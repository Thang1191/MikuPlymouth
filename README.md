# Dynamic Miku Plymouth Theme (Currently Fixing Bugs and Optimising Script. Come back later ;) )

**Artist Credit:** Original animations by [@x_cast_x](https://twitter.com/x_cast_x) on Twitter.
## Preview

https://github.com/user-attachments/assets/210208de-d814-414a-8e18-822979c38ce6

- The install script picks 10 random clips from a pool of 37 for every installation.
- The plymouth script also shuffle the 10 installed clips every boot.
- Optional systemd timer to rotate clips routine automatically every day. (Manual setup)

## Prerequisites

- `plymouth`
- `plymouth-plugin-script`

## Installation

### 1. Basic Setup
Clone and run the installer to pick 10 random clips from the pool and set them as your current boot theme:

```bash
git clone https://github.com/Thang1191/MikuPlymouth
cd MikuPlymouth
chmod +x install.sh
sudo ./install.sh
```
To choose certain clips, scroll down to **Customization**

### 2. Daily Automation (Recommended)
Because of RAM and `initramfs` size limits, only 10 clips are active at once. Use the systemd timer to rotate them automatically:

1. **Clone and move the project to a permanent location:**
   ```bash
   git clone https://github.com/Thang1191/MikuPlymouth
   sudo cp -r MikuPlymouth /opt/
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

Miku will now silently refresh her routine 1 minute after boot daily.

---

## Customization

### Method 1: Pool Pruning (Easiest)
If you only want certain clips to appear in the rotation:
- Go to `MikuPlymouth/miku_plymouth_clip_pool/`.
- Delete the folders or frames for clips you dislike.
- The next time the script runs (manually or via timer), it will only pick from your favorites.

### Method 2: Exact Selection
To force specific clips every time:
1. Open `install.sh`.
2. Locate the line: `selected_clips=$(echo "$available_clips" | shuf -n 10 | sort)`
3. Replace it with your specific clip IDs: `selected_clips="clip002 clip015 clip021"`
4. Run `./install.sh` manually to apply.

---

## System Limitations & Troubleshooting

### RAM Usage
Plymouth runs in uncompressed RAM and 1080p images are heavy! 
- **10 clips** (240 frames) use **~2GB of RAM**.(I think)
- Using more than 10 clips may cause the boot process to freeze or show a black screen depending on your hardware.

### Black Screen
- It is possible that plymouth has crashed. The easiest fix is to modify install.sh to install less clips/
- Locate the line: `selected_clips=$(echo "$available_clips" | shuf -n 10 | sort)`
- Lower the number "10" until it's usable (4 should be enough for lower end devices)

---

## Commands
- **Check Timer**: `systemctl list-timers miku-rotate.timer`
- **View Logs**: `journalctl -u miku-rotate.service`
