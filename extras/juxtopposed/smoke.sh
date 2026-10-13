#!/bin/bash
# Run inside the Linux build container, under dbus-run-session.
set -euo pipefail
cd /work
out=/work/build-m0/evidence
mkdir -p "$out" /work/build-m0/fixtures /work/build-m0/profile/runtime
export XDG_CONFIG_HOME=/work/build-m0/profile/config
export XDG_CACHE_HOME=/work/build-m0/profile/cache
export XDG_DATA_HOME=/work/build-m0/profile/data
export XDG_RUNTIME_DIR=/work/build-m0/profile/runtime
chmod 700 "$XDG_RUNTIME_DIR"
export QT_QPA_PLATFORM=xcb DISPLAY=:98
export LD_LIBRARY_PATH="/work/build-m0/deps/lib:${LD_LIBRARY_PATH:-}"
Xvfb :98 -screen 0 1280x800x24 -nolisten tcp > "$out/xvfb.log" 2>&1 &
xvfb_pid=$!
vlc_pid=
cleanup() {
    [[ -z "$vlc_pid" ]] || kill "$vlc_pid" 2>/dev/null || true
    kill "$xvfb_pid" 2>/dev/null || true
    pulseaudio --kill 2>/dev/null || true
}
trap cleanup EXIT
pulseaudio --start --exit-idle-time=-1 --load='module-null-sink sink_name=m0'
pactl set-default-sink m0
fixture=/work/build-m0/fixtures/baseline.mkv
if [[ ! -s "$fixture" ]]; then
    ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=640x360:rate=24 \
        -f lavfi -i sine=frequency=440:sample_rate=48000 -t 120 \
        -c:v libx264 -preset ultrafast -threads 2 -pix_fmt yuv420p \
        -c:a aac -y "$fixture"
fi
printf '1\n00:00:00,000 --> 00:02:00,000\nLegenda M0: reprodução real\n' \
    > /work/build-m0/fixtures/baseline.srt
sha256sum /work/build-m0/fixtures/baseline.* > "$out/fixtures.sha256"
sleep 1
cd /work/build-m0/linux
./vlc --ignore-config --no-qt-privacy-ask --no-one-instance --extraintf=dbus \
    --aout=pulse --sub-file=/work/build-m0/fixtures/baseline.srt \
    --verbose=2 "$fixture" > "$out/vlc.log" 2>&1 &
vlc_pid=$!
bus=org.mpris.MediaPlayer2.vlc
path=/org/mpris/MediaPlayer2
player=org.mpris.MediaPlayer2.Player
call() { gdbus call --session --dest "$bus" --object-path "$path" --method "$@"; }
get() { call org.freedesktop.DBus.Properties.Get "$player" "$1"; }
for attempt in $(seq 1 40); do
    status=$(get PlaybackStatus 2>/dev/null || true)
    [[ "$status" != *Playing* ]] || break
    kill -0 "$vlc_pid"
    sleep 1
done
[[ "$status" == *Playing* ]]
window=$(xdotool search --onlyvisible --pid "$vlc_pid" --name 'VLC' | head -1)
xdotool windowfocus --sync "$window"
sleep 2
import -window root "$out/playing.png"
get PlaybackStatus | tee "$out/playing.txt"
get Position | tee -a "$out/playing.txt"
ps -p "$vlc_pid" -o pid,comm,%cpu,rss,vsz,etime > "$out/resources.txt"
timeout 8 ffmpeg -hide_banner -loglevel error -f pulse -i m0.monitor \
    -t 2 -c:a pcm_s16le -y "$out/audio.wav"
python3 - "$out/audio.wav" <<'PY'
import array, math, sys, wave
with wave.open(sys.argv[1]) as stream:
    samples = array.array('h', stream.readframes(stream.getnframes()))
rms = math.sqrt(sum(v * v for v in samples) / len(samples))
print(f'Audio monitor PCM RMS: {rms:.2f}')
assert rms > 10, 'Audio output is silent'
PY
xdotool key --window "$window" space
sleep 1
get PlaybackStatus | tee "$out/paused.txt" | grep -q Paused
import -window root "$out/paused.png"
before=$(get Position)
sleep 1
after=$(get Position)
[[ "$before" == "$after" ]]
call "$player.Seek" 15000000 > "$out/seek.txt"
sleep 1
get Position | tee -a "$out/seek.txt"
python3 - "$before" "$(get Position)" <<'PY'
import re, sys
positions = [int(re.search(r'int64 (\d+)', value)[1]) for value in sys.argv[1:]]
assert abs(positions[1] - positions[0] - 15_000_000) < 1_000_000, positions
PY
before_volume=$(get Volume)
xdotool key --window "$window" ctrl+Down
sleep 1
after_volume=$(get Volume)
printf 'before=%s\nafter=%s\n' "$before_volume" "$after_volume" > "$out/volume.txt"
[[ "$before_volume" != "$after_volume" ]]
xdotool key --window "$window" space
sleep 1
get PlaybackStatus | tee "$out/resumed.txt" | grep -q Playing
xdotool key --window "$window" f
sleep 2
call org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2 Fullscreen \
    | tee "$out/fullscreen.txt" | grep -q true
import -window root "$out/fullscreen.png"
xdotool key f
sleep 1
call org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2 Fullscreen \
    | tee "$out/windowed.txt" | grep -q false
call org.mpris.MediaPlayer2.Quit > "$out/quit.txt"
wait "$vlc_pid"
vlc_pid=
printf 'PASS: Qt window, video, PCM audio, subtitle fixture, pause/resume, seek, volume, fullscreen, exit\n' \
    | tee "$out/result.txt"
