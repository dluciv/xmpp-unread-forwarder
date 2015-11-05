#!/bin/sh
pushd $(dirname `realpath $0`)
./node_modules/.bin/lsc xmppforward.ls __Some_very_private_folder__/xmppforward.cfg
popd
