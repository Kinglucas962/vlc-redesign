/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "http_request.hpp"

#include <QObject>
#include <QThread>

#include <memory>

#ifdef _WIN32
# include <windows.h>
# include <winhttp.h>

namespace {
struct InternetHandle
{
    HINTERNET handle;
    explicit InternetHandle(HINTERNET h) : handle(h) {}
    ~InternetHandle() { if (handle) WinHttpCloseHandle(handle); }
    InternetHandle(const InternetHandle&) = delete;
    InternetHandle& operator=(const InternetHandle&) = delete;
    explicit operator bool() const { return handle != nullptr; }
};

QString lastError(const char* step)
{
    return QStringLiteral("%1 failed (%2)").arg(QLatin1String(step)).arg(GetLastError());
}

HttpResponse perform(const HttpRequest& request)
{
    HttpResponse response;
    const QUrl& url = request.url;
    const bool https = url.scheme() == QLatin1String("https");
    if (!https && url.scheme() != QLatin1String("http"))
    {
        response.error = QStringLiteral("Unsupported URL scheme");
        return response;
    }

    InternetHandle session(WinHttpOpen(L"VLC", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                       WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0));
    if (!session)
    {
        response.error = lastError("WinHttpOpen");
        return response;
    }
    WinHttpSetTimeouts(session.handle, request.timeoutMs, request.timeoutMs,
                       request.timeoutMs, request.timeoutMs);

    const std::wstring host = url.host(QUrl::FullyEncoded).toStdWString();
    const auto port = static_cast<INTERNET_PORT>(url.port(https ? INTERNET_DEFAULT_HTTPS_PORT
                                                                : INTERNET_DEFAULT_HTTP_PORT));
    InternetHandle connection(WinHttpConnect(session.handle, host.c_str(), port, 0));
    if (!connection)
    {
        response.error = lastError("WinHttpConnect");
        return response;
    }

    const std::wstring method = QString::fromLatin1(request.method).toStdWString();
    const std::wstring path = QString::fromLatin1(
        url.toEncoded(QUrl::RemoveScheme | QUrl::RemoveAuthority | QUrl::RemoveFragment)).toStdWString();
    // Redirects are followed, except from HTTPS to HTTP (WinHTTP default policy).
    InternetHandle handle(WinHttpOpenRequest(connection.handle, method.c_str(),
                                             path.empty() ? L"/" : path.c_str(), nullptr,
                                             WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                             https ? WINHTTP_FLAG_SECURE : 0));
    if (!handle)
    {
        response.error = lastError("WinHttpOpenRequest");
        return response;
    }

    QByteArray headers;
    for (const auto& header : request.headers)
        headers += header.first + ": " + header.second + "\r\n";
    const std::wstring wideHeaders = QString::fromUtf8(headers).toStdWString();
    const auto bodySize = static_cast<DWORD>(request.body.size());
    if (!WinHttpSendRequest(handle.handle,
                            wideHeaders.empty() ? WINHTTP_NO_ADDITIONAL_HEADERS : wideHeaders.c_str(),
                            static_cast<DWORD>(-1L),
                            bodySize ? const_cast<char*>(request.body.constData()) : WINHTTP_NO_REQUEST_DATA,
                            bodySize, bodySize, 0)
        || !WinHttpReceiveResponse(handle.handle, nullptr))
    {
        response.error = lastError("HTTP request");
        return response;
    }

    DWORD status = 0;
    DWORD statusSize = sizeof(status);
    WinHttpQueryHeaders(handle.handle, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusSize, WINHTTP_NO_HEADER_INDEX);
    response.status = static_cast<int>(status);

    char buffer[16384];
    while (response.body.size() <= request.maxBytes)
    {
        DWORD read = 0;
        if (!WinHttpReadData(handle.handle, buffer, sizeof(buffer), &read))
        {
            response.error = lastError("WinHttpReadData");
            break;
        }
        if (read == 0)
            break;
        response.body.append(buffer, read);
    }
    if (response.body.size() > request.maxBytes)
        response.body.truncate(request.maxBytes + 1);
    return response;
}
}

bool httpRequestSupported()
{
    return true;
}
#else
namespace {
HttpResponse perform(const HttpRequest&)
{
    HttpResponse response;
    response.error = QStringLiteral("No HTTP backend in this build");
    return response;
}
}

bool httpRequestSupported()
{
    return false;
}
#endif

void httpRequestAsync(QObject* context, HttpRequest request,
                      std::function<void(const HttpResponse&)> done)
{
    auto response = std::make_shared<HttpResponse>();
    QThread* thread = QThread::create([request = std::move(request), response]() {
        *response = perform(request);
    });
    // The context connection drops done if context goes away first.
    QObject::connect(thread, &QThread::finished, context,
                     [response, done = std::move(done)]() { done(*response); });
    QObject::connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}
