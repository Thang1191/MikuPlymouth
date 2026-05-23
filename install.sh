#!/bin/bash
# MikuPlymouth Dynamic Installer
# This script picks random clips from the pool and sets them up.

# Ensure script runs as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (e.g., sudo ./install.sh)"
    exit 1
fi

POOL_DIR="miku_plymouth_clip_pool"
THEME_DIR_LOCAL="MikuPlymouth"
THEME_DIR_SYS="/usr/share/plymouth/themes/MikuPlymouth"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
GRUB_CONF="/etc/default/grub"

if [ ! -d "$POOL_DIR" ]; then
    echo "Error: $POOL_DIR not found!"
    exit 1
fi

echo "Step 1: Cleaning up local theme folder..."
mkdir -p "$THEME_DIR_LOCAL"
rm -f "$THEME_DIR_LOCAL"/*.png

echo "Step 2: Picking clips from the pool..."
# Get unique clip numbers from the pool
available_clips=$(ls "$POOL_DIR" | grep -o 'clip[0-9]*' | sort -u)
num_available=$(echo "$available_clips" | wc -l)

# Pick up to 10, or fewer if less are available
pick_count=10
if [ "$num_available" -lt "$pick_count" ]; then
    pick_count=$num_available
fi

selected_clips=$(echo "$available_clips" | shuf -n "$pick_count" | sort)
echo "Selected $pick_count clips: $(echo $selected_clips | xargs)"

# Store IDs and frame counts for the script generation
clip_ids=()
clip_frames=()

for clip in $selected_clips; do
    id_raw=$(echo "$clip" | sed 's/clip//')
    # Remove leading zeros for the script math, but handle "000" -> "0"
    id=$(echo "$id_raw" | sed 's/^0*//')
    if [ -z "$id" ]; then id=0; fi
    
    # Count frames for this specific clip
    frame_count=$(ls "$POOL_DIR/${clip}_frame"* | wc -l)
    
    clip_ids+=($id)
    clip_frames+=($frame_count)
    
    echo "Copying $clip ($frame_count frames)..."
    cp "$POOL_DIR/${clip}_frame"* "$THEME_DIR_LOCAL/"
done

echo "Step 3: Generating MikuPlymouth.script..."
cat << EOF > "$THEME_DIR_LOCAL/MikuPlymouth.script"
# MikuPlymouth.script - Dynamically Generated
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

# Configuration
EOF

# Add the clip IDs and frame counts to the script
i=0
for id in "${clip_ids[@]}"; do
    echo "clip_list[$i] = $id;" >> "$THEME_DIR_LOCAL/MikuPlymouth.script"
    echo "clip_frames[$i] = ${clip_frames[$i]};" >> "$THEME_DIR_LOCAL/MikuPlymouth.script"
    i=$((i+1))
done

cat << EOF >> "$THEME_DIR_LOCAL/MikuPlymouth.script"
total_clips = $pick_count;

# Pad numbers to 3 digits (e.g., 5 -> 005)
fun pad3(n) {
    if (n < 10) return "00" + n;
    if (n < 100) return "0" + n;
    return "" + n;
}

# Shuffle once at start
for (i = total_clips - 1; i > 0; i--) {
    j = Math.Int(Math.Random() * (i + 1));
    temp = clip_list[i];
    clip_list[i] = clip_list[j];
    clip_list[j] = temp;
    # Shuffle frame counts too
    temp_f = clip_frames[i];
    clip_frames[i] = clip_frames[j];
    clip_frames[j] = temp_f;
}

# Pre-load the first frame for instant display
first_id = clip_list[0];
miku_sprite = Sprite();
first_img = Image("clip" + pad3(first_id) + "_frame1.png");
miku_sprite.SetImage(first_img);

# Position
screen.w = Window.GetWidth(0);
screen.h = Window.GetHeight(0);
miku_sprite.SetX(Window.GetX() + (screen.w / 2 - first_img.GetWidth() / 2));
miku_sprite.SetY(Window.GetY() + (screen.h / 2 - first_img.GetHeight() / 2));

# Pre-load all frames
frame_ptr = 0;
for (c = 0; c < total_clips; c++) {
    t_id = clip_list[c];
    t_frames = clip_frames[c];
    clip_start_idx[c] = frame_ptr;
    for (f = 0; f < t_frames; f++) {
        img[frame_ptr + f] = Image("clip" + pad3(t_id) + "_frame" + (f + 1) + ".png");
    }
    frame_ptr += t_frames;
}

cur_idx = 0;
frame_in_clip = 0;

fun refresh_callback () {
    # 24 FPS logic (assuming 50Hz or 60Hz refresh, but Plymouth refresh is variable)
    # Simplified: increment frame each callback (usually ~50-60fps)
    # Adjusting to roughly 24fps by skipping every other frame if needed
    # For now, let's keep it simple:
    
    miku_sprite.SetImage(img[clip_start_idx[cur_idx] + frame_in_clip]);
    
    frame_in_clip++;
    if (frame_in_clip >= clip_frames[cur_idx]) {
        frame_in_clip = 0;
        cur_idx = (cur_idx + 1) % total_clips;
    }
}
Plymouth.SetRefreshFunction(refresh_callback);

# Boilerplate
fun DisplayQuestionCallback(p,e){} Plymouth.SetDisplayQuestionFunction(DisplayQuestionCallback);
fun DisplayPasswordCallback(n,b){} Plymouth.SetDisplayPasswordFunction(DisplayPasswordCallback);
fun DisplayNormalCallback(){} Plymouth.SetDisplayNormalFunction(DisplayNormalCallback);
fun MessageCallback(t){} Plymouth.SetMessageFunction(MessageCallback);
EOF

echo "Step 4: Ensuring System Requirements (NVIDIA/KMS)..."
if [ -f "$GRUB_CONF" ]; then
    if ! grep -q "nvidia-drm.modeset=1" "$GRUB_CONF"; then
        echo "Adding nvidia-drm.modeset=1 to GRUB..."
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' "$GRUB_CONF"
        if command -v update-grub &> /dev/null; then
            update-grub
        elif [ -f /boot/grub/grub.cfg ]; then
            grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
fi

if [ -f "$MKINITCPIO_CONF" ]; then
    if ! grep -q "nvidia" "$MKINITCPIO_CONF" | grep -q "MODULES=("; then
        echo "Adding nvidia modules to mkinitcpio..."
        sed -i 's/MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' "$MKINITCPIO_CONF"
    fi
fi

echo "Step 5: Installing to system..."
mkdir -p "$THEME_DIR_SYS"
rm -f "$THEME_DIR_SYS"/*.png
cp "$THEME_DIR_LOCAL"/* "$THEME_DIR_SYS/"

echo "Step 6: Rebuilding initramfs..."
plymouth-set-default-theme -R MikuPlymouth

if command -v dracut &> /dev/null; then
    echo "Dracut detected..."
    dracut --force
elif command -v mkinitcpio &> /dev/null; then
    echo "mkinitcpio detected..."
    mkinitcpio -P
elif command -v update-initramfs &> /dev/null; then
    echo "initramfs detected..."
    update-initramfs -u -k all
else
    echo "Warning: No known initramfs generator found."
fi

echo "Done! Reboot to see MIKU."
