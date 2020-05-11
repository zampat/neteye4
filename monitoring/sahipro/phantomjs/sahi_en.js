"use strict";
var page = require('webpage').create(),
    system = require('system'),
    address,
    output,
    size;

if (system.args.length < 3) {
    console.log('Usage: sahi.js <log-dir> <playback start URL>');
    phantom.exit(1);
} else {
    var ldir = system.args[1];
    console.log('DIR: ' + ldir);
    address = system.args[2];
    console.log('URL: ' + address);
    page.viewportSize = { width: '1280', height: '1024' };
    page.paperSize = {format: 'A4', orientation: 'portrait', margin: '1cm' };
    page.settings.userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36';
    page.customHeaders = {
        "Accept-Language": "en-US,en"
    };
    page.open(address, function(status) {
        if (status === 'success') {
            var title = page.evaluate(function() {
                return document.title;
            });
            console.log('Page title is ' + title);
        } else {
            console.log('FAIL to load the address');
        }
    });
    page.onLoadFinished = function(status) {
        page.render(ldir + '/sahiurl.png');
        console.log('Status: ' + status);
    };
}
