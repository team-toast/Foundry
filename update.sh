#!/bin/bash

set -e

echo "compressing dist/"
tar -cf dist.tar dist

echo "Updating permafrost.foundrydao.com"
echo "transferring dist.tar"
scp -i $2 dist.tar $1@permafrost.foundrydao.com:~/update/
echo "calling remote update script"
ssh -i $2 $1@permafrost.foundrydao.com '\/bin/update.sh'

echo "remote update finished, removing tar"
rm dist.tar
