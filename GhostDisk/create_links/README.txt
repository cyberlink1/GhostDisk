===============================================================
                  AUTO-LINKING SYSTEM README
===============================================================

This system allows you to securely move, store, and link files
from your home directory to an encrypted storage location.
It is designed to work with LXQt, XFCE, and LUKS-encrypted
volumes mounted via udiskie.

----------------------------------------
FILES AND SCRIPTS
----------------------------------------

1. build-it.sh
   - Copies the necessary files into the correct locations 
     for live-build to include them in your build.

2. autolink
   - Used by autolink.desktop to create the links automatically 
     when you login or unlock the encrypted drive.

3. autolink.desktop
   - Desktop entry run by the autostart system in LXQt/XFCE.
   - Launches the autolink script at login.

4. create_links
   - Creates the symbolic links from your home directory 
     to the encrypted storage.

5. make_links
   - Provides a GUI to configure what files/directories 
     should be linked and which should not.
   - Saves the configuration to ~/.Encrypted/.cl.cfg

6. move_and_link
   - Used on initial setup.
   - Moves existing files and directories from your home
     directory into the encrypted storage.
   - Sets up the corresponding symbolic links.

7. ~/Encrypted/.cl.cfg
   - The main configuration file for the system.
   - Lists what is to be linked and where.
   - Format:

       <+/->|<f/d>|<file or directory location>|<Encrypted storage location>

     Example entries:

       +|f|~/Documents/notes.txt|~/Encrypted/vault
       -|d|~/Pictures|~/Encrypted/pics
       +|d|.config/lxqt|~/Encrypted

   - "+" means the item is enabled and will be linked.
   - "-" means the item is disabled.

----------------------------------------
USAGE
----------------------------------------

1. Initial Setup:
   - Run move_and_link to move files into encrypted storage 
     and create links.

2. Configuring Links:
   - Use make_links to select which files/directories 
     should be linked.

3. Autolinking at Login:
   - The autolink.desktop file ensures links are created 
     automatically when your encrypted volume is mounted.

4. Manual Link Creation:
   - create_links can be run manually to create links 
     according to the configuration file.

----------------------------------------
NOTES
----------------------------------------

- The system will wait for the ~/Encrypted volume to be 
  mounted before creating links. If the volume is not mounted,
  no links will be created.
- The scripts are safe to run multiple times; they will 
  overwrite existing symlinks if necessary.
- Works for both files and directories, including hidden
  files such as .config or .profile.
- The default .cl.cfg is added to your encrypted storage when 
  you set it up under the Grub setup opton.
- These files are not automaticly installed if changed. The following
  locations are where you would need to put them.
      config/includes.chroot/usr/bin/autolink
      config/includes.chroot/etc/xdg/autostart/autolink.desktop
      config/includes.chroot/usr/bin/create_links
      config/includes.chroot/usr/bin/make_links
      config/includes.chroot/usr/bin/move_and_link
      config/includes.chroot/usr/share/applications/setup-links.desktop
===============================================================
End of README
===============================================================

