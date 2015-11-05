var path = require('path'),
    fs   = require('fs'),
    lsc = require('livescript/lib/command');

var xfwls  = path.join(path.dirname(fs.realpathSync(__filename)), '../xmppforward.ls');

lsc([process.argv[0], "lsc", xfwls, process.argv[2]]);
