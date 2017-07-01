# wallet-backup
A bash script for backing up (several different types of) cryptocurrency wallets

NOTE: When you are using this wallet, you take full responsibility for using this application.

Installation:

rust (at least v1.19):
- Download from here: https://www.rust-lang.org/en-US/other-installers.html. For example: x86_64-unknown-linux-gnu
- Untar and run the installer as root

rdedup
- Run cargo install rdedup (not as root)
- Add cargo bin path to your PATH. For example add this to ~/.bashrc:
export PATH=/home/YOUR_USERNAME/.cargo/bin::$PATH

rdup-up
- install from your operating system's repository. For example: apt install rdup
