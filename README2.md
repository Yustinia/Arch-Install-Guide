# Arch Linux Install Script

A helpful bash script that setups and installs Arch Linux with little user intervention.

## Installation Stages

Each numbered step is how the script operates.

---

### **1. Preparation & Partitioning**
- Select and partition the drive (EFI + encrypted root partition)

### **2. Disk Encryption (LUKS)**
- Set up full-disk encryption on the root partition and open the encrypted container

### **3. Btrfs Formatting & Subvolume Setup**
- Format the encrypted partition as Btrfs
- Create all required and optional subvolumes (@, @home, @var_log, etc.)

### **4. Mounting Subvolumes**
- Mount the subvolumes with proper options (compression, noatime, nodatacow where needed)
- Mount the EFI partition

### **5. Base System Installation**
- Install base Arch Linux system and essential packages via pacstrap
- Generate initial fstab

### **6. Chroot into the New System**
- Enter the installed system with arch-chroot for further configuration

### **7. Swap Setup**
- Create and configure a Btrfs swapfile (or swap subvolume) for hibernation support

### **8. Zram Configuration**
- Install and configure zram-generator for compressed in-memory swap

### **9. Localization & Time**
- Set timezone, hardware clock, locale, vconscole, and hostname/hosts file

### **10. User & Root Account Setup**
- Set root password
- Create main user account with sudo privileges

### **11. System Services**
- Enable essential services (NetworkManager, etc.)

### **12. GRUB Bootloader Configuration**
- Configure GRUB for encrypted root (cryptodisk, correct kernel parameters and UUIDs)
- Install GRUB to EFI system

### **13. Initramfs Regeneration (mkinitcpio)**
- Modify hooks and modules to support LUKS encryption and Btrfs
- Regenerate initramfs

### **14. Final Touches & Reboot**
- Optional GRUB tweaks (timeout, saved default, etc.)
- Unmount everything and reboot into the new system

---

## Controller

Execute each stage through the main
