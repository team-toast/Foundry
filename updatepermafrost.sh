#!/bin/bash

set -e

branch_name="$(git symbolic-ref HEAD 2>/dev/null)" ||
branch_name="(unnamed branch / detached head)"
branch_name=${branch_name##refs/heads/}

if [ $branch_name != "permafrost_live" ]; then
  echo "Not on the right branch! Exiting."
  exit 1
fi

echo "compressing dist/"
tar -cf dist.tar dist

echo "Updating sale.foundrydao.com"
echo "transferring dist.tar"
scp -i $2 dist.tar $1@sale.foundrydao.com:~/update/
echo "calling remote update script"
ssh -i $2 $1@sale.foundrydao.com '\/bin/update.sh'

echo "remote update finished, removing tar"
rm dist.tar
