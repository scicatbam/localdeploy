#!/bin/sh
# Builds all SciCat services and pushes the images to the registry
# as defined by $SC_SITECONFIG/general.rc
#
# Add this script to a crontab like this:
# cd; export SC_SITECONFIG=$HOME/scicat/osd; $HOME/scicat/deploy/daily_build.sh > $HOME/scicat/buildlog/log.md 2>&1; (cd $HOME/scicat/buildlog; git commit -m "latest build" log.md && git push)
# -> do not forget to
# - clone the deploy script repo
# - clone the buildlog repo, set user&pwd, upload ssh keys
# - add the building user to the docker group
# - copy the $SC_SITECONFIG/general.rc from elsewhere

# get the script directory before creating any files
scriptdir="$(dirname "$(readlink -f "$0")")"

postprocess() {
    local logfn; logfn="$(readlink -f "$1")"
    local logpath; logpath="$(dirname "$logfn")"
    cd "$logpath"
    # using https://github.com/ekalinin/github-markdown-toc
    if command -v gh-md-toc > /dev/null; then
        local tmpfn="$(mktemp)"
        (gh-md-toc "$logfn" | head -n-1; cat "$logfn") > "$tmpfn"
        mv "$tmpfn" "$logfn"
    fi
    git commit -m "latest build" log.md && git push
}

if [ ! -z "$1" ] && [ -f "$1" ]; then
    postprocess "$1"
    exit
fi

ts() {
    date +%s
}
timeFmt() {
    local secs="$1"
    if [ "$secs" -lt 60 ]; then
        echo "$secs s"
    else
        echo "$((secs/60)) m, $((secs-60*(secs/60))) s"
    fi
}

timeSum=0
echo "# Updating the deploy script"
echo '```'
cd "$scriptdir"
git stash save && git pull --rebase && git stash pop
echo '```'

for svc in catamel catanie landing scichat-loopback;
do
    echo "# $svc"
    start=$(ts)
    echo "Attempting build at $(date)"
    echo '```'
    sh "$scriptdir/services/$svc"/*.sh buildonly
    echo '```'
    timeDelta=$(($(ts)-start))
    timeSum=$((timeSum+timeDelta))
    echo "Building $svc took $(timeFmt $timeDelta)."
    echo
done
echo "Overall time: $(timeFmt $timeSum)."


# vim: set ts=4 sw=4 sts=4 tw=0 et: