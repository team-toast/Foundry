#!/bin/bash

set -e

echo "compressing dist/"
tar -cf dist.tar dist

echo "Updating sale.foundrydao.com"
echo "transferring dist.tar"
scp -i $2 dist.tar $1@sale.foundrydao.com:~/update/
echo "calling remote update script"
ssh -i $2 $1@sale.foundrydao.com '~/bin/update'

echo "remote update finished, removing tar"
rm dist.tar
