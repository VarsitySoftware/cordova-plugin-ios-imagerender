var ImageRender = function ()
{

};

ImageRender.prototype.run = function (success, fail, options)
{
    if (!options) {
        options = {};
    }

    var params = {
        type: options.type ? options.type : 0,
        url: options.url ? options.url : null,
        filter: options.filter ? options.filter : null,
        cssPath: options.cssPath ? options.cssPath : null,
        overlayBase64: options.overlayBase64 ? options.overlayBase64 : null,
        loadDelay: options.loadDelay ? options.loadDelay : null,
        quality: options.quality ? options.quality : 0
    };

    return cordova.exec(success, fail, "ImageRender", "run", [params]);

};

window.imageRender = new ImageRender();
