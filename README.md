# Dynamic Miku Plymouth Theme (24 FPS)

A cinematic, high-definition animated boot splash for Linux (Arch/CachyOS) featuring Hatsune Miku. This system uses a unique dynamic rotation engine to give you a fresh, zero-lag animation every time you boot.

**Artist Credit:** Original animations by [@x_cast_x](https://twitter.com/x_cast_x) on Twitter.

---

## ✨ Features

- **Silky Smooth 24 FPS**: Expertly timed animation logic.
- **Zero-Lag Transitions**: All frames are pre-loaded into RAM during the early boot phase.
- **Instant Start**: The theme displays the first frame immediately while pre-loading the rest in the background to prevent black screens.
- **Dynamic Rotation**: Pick 10 random clips from a pool of 37+ for every installation.
- **Daily Variety**: Optional systemd timer to rotate Miku's routine automatically every day.

## 📋 Prerequisites

- `plymouth`
- `plymouth-plugin-script`
- `mkinitcpio` (Arch-based systems)
- **NVIDIA Users**: Requires Early KMS enabled (see Troubleshooting).

---

## 🚀 Installation

### 1. Basic Setup
Run the installer to pick 10 random clips from the pool and set them as your current boot theme:

```bash
chmod +x install.sh
sudo ./install.sh
```

### 2. Daily Automation (Recommended)
Because of RAM and `initramfs` size limits, only 10 clips are active at once. Use the systemd timer to rotate them automatically:

1. **Move the project to a permanent location:**
   ```bash
   sudo mkdir -p /opt/MikuPlymouth
   sudo cp -r ./* /opt/MikuPlymouth/
   ```

2. **Install the automation files:**
   ```bash
   sudo cp /opt/MikuPlymouth/miku-rotate.service /etc/systemd/system/
   sudo cp /opt/MikuPlymouth/miku-rotate.timer /etc/systemd/system/
   ```

3. **Activate the timer:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now miku-rotate.timer
   ```

Miku will now silently refresh her routine 10 seconds after every boot.

---

## 🛠️ Customization

### Method 1: Pool Pruning (Easiest)
If you only want certain clips to appear in the rotation:
- Go to `/opt/MikuPlymouth/miku_plymouth_clip_pool/`.
- Delete the folders or frames for clips you dislike.
- The next time the script runs (manually or via timer), it will only pick from your favorites.

### Method 2: Exact Selection
To force specific clips every time:
1. Open `install.sh`.
2. Locate the line: `selected_clips=$(echo "$available_clips" | shuf -n 10 | sort)`
3. Replace it with your specific clip IDs: `selected_clips="clip002 clip015 clip021"`
4. Run `./install.sh` manually to apply.

---

## ⚠️ System Limitations & Troubleshooting

### RAM Usage
Plymouth runs in uncompressed RAM. 1080p images are heavy! 
- **10 clips** (240 frames) use **~2GB of RAM**.
- Using more than 10 clips may cause the boot process to freeze or show a black screen depending on your hardware.

### NVIDIA Early KMS (Mandatory for RTX/GTX Cards)
If you see a black screen or the animation only shows up right before the login screen, you must enable Early KMS:

1. Edit `/etc/mkinitcpio.conf` and add the drivers to the `MODULES` array:
   `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`
2. Ensure your GRUB command line in `/etc/default/grub` contains:
   `quiet splash nvidia-drm.modeset=1`
3. Rebuild GRUB and Initramfs:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   sudo mkinitcpio -P
   ```

---

## 🔍 Commands
- **Manual Rotation**: `sudo /opt/MikuPlymouth/install.sh`
- **Check Timer**: `systemctl list-timers miku-rotate.timer`
- **View Logs**: `journalctl -u miku-rotate.service`
- **Test Preview (In-Session)**: 
  `xhost +local:root && sudo plymouthd --no-daemon --x11 & sleep 2 && sudo plymouth --show-splash`
