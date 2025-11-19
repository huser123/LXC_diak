  df -h
  lsblk -f
  sudo lvdisplay
  sudo vgdisplay
  sudo pvdisplay
  sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
  sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
  df -h
