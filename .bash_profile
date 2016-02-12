clear
#tput rev
echo "┌─────────────────────────────────────────────────────────────────────────┐"
echo "│  Welcome, you are logged in as '${USER}' on host $(hostname)           │"
#echo "├─────────────────────────────────────────────────────────────────────────┤"
echo "│ Configuring your environment:                                           │"


### Environment variables
echo "│ ✔ setting environment variables                                         │"
#export PS1="[\u@\h \w]$ "
#export PS1="\\[\033[38;5;255m\]\[\033[48;5;21m\] \u \\[\033[38;5;21m\]\[\033[48;5;39m\] \h \\[\033[38;5;27m\]\[\033[48;5;51m\] \w\\[\033[38;5;21m\] \[$(tput bold)\]\[\033[38;5;28m\]\[\033[48;5;10m\]>\[$(tput sgr0)\] "
export PS1="\[$(tput bold)\]\[\033[38;5;208m\][\[$(tput sgr0)\]\[\033[38;5;148m\]\u\[$(tput sgr0)\]\[\033[38;5;117m\]@\[$(tput sgr0)\]\[\033[38;5;51m\]\h\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput bold)\]\[$(tput sgr0)\]\[\033[38;5;211m\]\w\[$(tput sgr0)\]\[\033[38;5;208m\]]\[$(tput sgr0)\]\[\033[38;5;253m\]\\$\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]"
#export PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"
#export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_60.jdk/Contents/Home"
export JRE_HOME=$JAVA_HOME
export M2_HOME="/opt/apache-maven-3.2.5"
export MYSQL_HOME="/usr/local/mysql"
export GOPATH="/Users/rprins/Development/goprojects"
#export MULE_HOME="/opt/mule-enterprise-standalone-3.7.3"
export PATH=$PATH:$HOME/bin:$M2_HOME/bin:$MYSQL_HOME/bin:$GOROOT
# MacPorts Installer addition on 2015-12-01_at_15:22:35: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.


### Aliases and shortcuts
echo "│ ✔ setting aliases                                                       │"
alias cls="clear;ls"
alias mci="mvn clean install -U -e -DskipTests=true"
alias mcit="mvn clean install -U -e"
alias mcit="mvn clean install"
alias mci="mvn clean install -DskipTests=true"
alias mcc="mvn clean compile -U -e -DskipTests=true"
alias mcct="mvn clean compile -U -e"
alias mee="mvn eclipse:eclipse"
alias mcee="mvn eclipse:clean eclipse:eclipse"
alias eclipse="/Users/rprins/Applications/eclipse/Eclipse.app/Contents/MacOS/eclipse -clean &"
alias studio="/Users/rprins/Applications/AnypointStudio/AnypointStudio.app/Contents/MacOS/AnypointStudio -clean &"
alias edit="subl"
alias portscan="/System/Library/CoreServices/Applications/Network\ Utility.app/Contents/Resources/stroke"
alias fixow="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain user;echo 'Open With has been rebuilt. Relauching Finder...';killall Finder"
alias fixvirtualbox="sudo /Library/StartupItems/VirtualBox/VirtualBox restart"

alias fixarchiveutility='echo "Archive Utility - stopping appleevents deamon.";sudo killall -KILL appleeventsd;echo "Please restart your machine."'
alias git-revert="echo 'Reverting local git to origin/master';git fetch origin;git reset --hard origin/master;echo 'Done.'"
alias wifi-diag="open '/System/Library/CoreServices/Applications/Wireless Diagnostics.app'"
alias nwutil="open '/System/Library/CoreServices/Applications/Network Utility.app'"
alias am="open '/Applications/Utilities/Activity Monitor.app'"
alias enable_awdl="echo 'Enabling AWDL (Airdrop) interface.';sudo ifconfig awdl0 up"
alias disable_awdl="echo 'Disabling AWDL (Airdrop) interface.';sudo ifconfig awdl0 down"
alias enable_icloud="echo 'Enabling iCloud for open file dialogs.';defaults write -g NSShowAppCentricOpenPanelInsteadOfUntitledFile true"
alias disable_icloud="echo 'Disabling iCloud for open file dialogs.';defaults write -g NSShowAppCentricOpenPanelInsteadOfUntitledFile false"
alias enable_suddenmotion="echo 'Enabling sudden motion sensor.';sudo pmset -a sms 1"
alias disable_suddenmotion="echo 'Disabling sudden motion sensor.';sudo pmset -a sms 0"
alias enable_spotlight="echo 'Enabling spotlight.';sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist"
alias disable_spotlight="echo 'Disabling spotlight.';sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist"
alias enable_dynamic_pager="echo 'Enabling dynamic pager.';sudo launchctl load -wF /System/Library/LaunchDaemons/com.apple.dynamic_pager.plist;echo 'Please restart your machine.'"
alias disable_dynamic_pager="echo 'Disabling dynamic pager.';sudo launchctl unload -wF /System/Library/LaunchDaemons/com.apple.dynamic_pager.plist;echo 'Please restart your machine.'"
alias show_hidden_files="echo 'Show hidden files in Finder';defaults write com.apple.finder AppleShowAllFiles -bool YES;echo 'Done. Restarting Finder...';killall Finder"
alias hide_hidden_files="echo 'Hide hidden files in Finder';defaults write com.apple.finder AppleShowAllFiles -bool NO;echo 'Done. Restarting Finder...';killall Finder"
alias reset_dns_cache="echo 'Resetting local DNS cache.';sudo discoveryutil mdnsflushcache;sudo discoveryutil udnsflushcaches;say flushed"
alias reset_font_cache="echo 'Resetting font cache(s)';sudo atsutil databases -remove;echo 'Done.'"
alias show_library="echo 'Show Library folder in Finder';chflags nohidden ~/Library/"
alias hide_library="echo 'Hiding Library folder in Finder';chflags hidden ~/Library/"
alias standby_delay_1hr="echo 'Setting standy delay to 1 hour';sudo pmset -a standbydelay 4200"
alias standby_delay_24hr="echo 'Setting standy delay to 24 hours';sudo pmset -a standbydelay 86400"
alias timemachine_log="echo 'Time machine log:';syslog -F '$Time $Message' -k Sender com.apple.backupd -k Time ge -72h | tail -n 10"
alias reset_chrome_dialog="defaults delete com.google.Chrome NSNavPanelExpandedSizeForOpenMode;defaults delete com.google.Chrome NSNavPanelExpandedSizeForSaveMode"

alias ssh-aws-proxy="ssh -i ~/.ssh/services-training-proxy.pem ubuntu@ec2-52-26-157-157.us-west-2.compute.amazonaws.com"
alias ssh-aws-jenkins="ssh -i ~/.ssh/trainingjenkins.pem ubuntu@ec2-54-68-153-44.us-west-2.compute.amazonaws.com"
echo "└─────────────────────────────────────────────────────────────────────────┘"
tput sgr0
echo
