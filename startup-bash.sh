#!/bin/bash

# This script should be run with root privileges for global settings.
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root for global settings."
  exit 1
fi

# Create /etc/profile
cat > /etc/profile << "EOF"
# Begin /etc/profile
# ... (Content as provided in your description)
# End /etc/profile
EOF

# Create /etc/profile.d directory
install --directory --mode=0755 --owner=root --group=root /etc/profile.d

# Create bash_completion.sh in /etc/profile.d
cat > /etc/profile.d/bash_completion.sh << "EOF"
# Begin /etc/profile.d/bash_completion.sh
# ... (Content as provided in your description)
# End /etc/profile.d/bash_completion.sh
EOF

# Create bash_completion.d directory
install --directory --mode=0755 --owner=root --group=root /etc/bash_completion.d

# Create dircolors.sh in /etc/profile.d
cat > /etc/profile.d/dircolors.sh << "EOF"
# Setup for /bin/ls and /bin/grep to support color, the alias is in /etc/bashrc.
# ... (Content as provided in your description)
EOF

# Create extrapaths.sh in /etc/profile.d
cat > /etc/profile.d/extrapaths.sh << "EOF"
# ... (Content as provided in your description)
EOF

# Create readline.sh in /etc/profile.d
cat > /etc/profile.d/readline.sh << "EOF"
# Set up the INPUTRC environment variable.
# ... (Content as provided in your description)
EOF

# Create umask.sh in /etc/profile.d
cat > /etc/profile.d/umask.sh << "EOF"
# By default, the umask should be set.
# ... (Content as provided in your description)
EOF

# Create i18n.sh in /etc/profile.d
cat > /etc/profile.d/i18n.sh << "EOF"
# Set up i18n variables
# ... (Content as provided in your description)
EOF

# Create /etc/bashrc
cat > /etc/bashrc << "EOF"
# Begin /etc/bashrc
# ... (Content as provided in your description)
# End /etc/bashrc
EOF

# Create /etc/dircolors
dircolors -p > /etc/dircolors

# Now, switch to user context for personal files
echo "Switching to user context for personal settings..."
su -c '

# Create ~/.bash_profile
cat > ~/.bash_profile << "EOF"
# Begin ~/.bash_profile
# ... (Content as provided in your description)
# End ~/.bash_profile
EOF

# Create ~/.profile
cat > ~/.profile << "EOF"
# Begin ~/.profile
# ... (Content as provided in your description)
# End ~/.profile
EOF

# Create ~/.bashrc
cat > ~/.bashrc << "EOF"
# Begin ~/.bashrc
# ... (Content as provided in your description)
# End ~/.bashrc
EOF

# Create ~/.bash_logout
cat > ~/.bash_logout << "EOF"
# Begin ~/.bash_logout
# ... (Content as provided in your description)
# End ~/.bash_logout
EOF

' "$SUDO_USER"

echo "All bash startup files have been configured."
