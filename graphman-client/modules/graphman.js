
const utils = require("./graphman-utils");
const hutils = require("./http-utils");
const CONFIG = JSON.parse(utils.readFile(utils.home() + "/graphman.configuration"));

const PRE_REQUEST_EXTN = utils.extension("graphman-pre-request");
const PRE_RESPONSE_EXTN = utils.extension("graphman-pre-response");
const http = require("http");
const https = require("https");

module.exports = {
    configuration: function (params) {
        let config = Object.assign({}, CONFIG);

        if (params) {
            if (params.sourceGateway) {
                Object.assign(config.sourceGateway, params.sourceGateway);
            }

            if (params.targetGateway) {
                Object.assign(config.targetGateway, params.targetGateway);
            }
        }

        return config;
    },

    request: function (gateway, body) {
        const url = new URL(gateway.address);
        const headers = {
            'content-type': 'application/json; charset=utf-8'
        };

        if (gateway.passphrase) {
            headers['l7-passphrase'] = gateway.passphrase;
        }

        const req = {
            host: url.hostname,
            port: url.port || 443,
            path: url.pathname || '/graphman',
            protocol: url.protocol,
            method: 'POST',
            rejectUnauthorized: gateway.rejectUnauthorized,
            headers: headers,
            auth: gateway.username + ":" + gateway.password,
            body: body || {}
        };

        req.minVersion = req.maxVersion = gateway.tlsProtocol || "TLSv1.2";
        return req;
    },

    invoke: function (options, callback) {
        PRE_REQUEST_EXTN.call(options);
        const req = ((!options.protocol||options.protocol === 'https'||options.protocol === 'https:') ? https : http).request(options, function(response) {
            let respInfo = {initialized: false, chunks: []};

            response.on('data', function (chunk) {
                if (!respInfo.initialized) {
                    utils.debug("graphman http response headers", response.headers);
                    respInfo = Object.assign(respInfo, hutils.parseHeader('contentType', response.headers['content-type']));
                    respInfo.isMultipart = respInfo.contentType.startsWith("multipart/");
                    respInfo.initialized = true;
                    if (respInfo.isMultipart) utils.info("http multipart response is detected, boundary=" + respInfo.boundary);
                }

                respInfo.chunks.push(chunk);
            });

            response.on('end', function () {
                let data = Buffer.concat(respInfo.chunks);

                if (respInfo.contentType.startsWith('application/json')) {
                    const jsonData = JSON.parse(data);
                    utils.debug("graphman http response", jsonData);
                    PRE_RESPONSE_EXTN.call(jsonData);
                    callback(jsonData);
                } else if (respInfo.contentType.startsWith('multipart/')) {
                    utils.debug("graphman http multipart response");
                    let parts = hutils.readParts(data, respInfo.boundary);
                    callback(JSON.parse(parts[0].data), parts);
                } else {
                    utils.info("unexpected graphman http response");
                    utils.info(data);
                    callback({error: data, data: {}});
                }
            });
        });

        req.on('error', (err) => {
            utils.warn(`error encountered while processing the graphman request: ${err.message}`);
        });

        utils.debug("graphman http request", maskedHttpRequest(options));

        if (isMultipart(options)) {
            hutils.writeParts(req, getPartsFromRawRequest(options));
        } else {
            req.write(JSON.stringify(options.body));
        }

        req.end();
    }
}

function maskedHttpRequest(options) {
    if (options.auth) options.auth = "***";
    if (options.headers['l7-passphrase']) options.headers['l7-passphrase'] = "***";
    if (options.headers.encpass) options.headers.encpass = "***";
    return options;
}

function isMultipart(options) {
    return Array.isArray(options.parts);
}

function getPartsFromRawRequest(options) {
    const mainPart = options.parts[0];

    //first part should contain main request data
    if (!mainPart.data) {
        mainPart.name = "operations";
        mainPart.contentType = "application/json; charset=utf-8";
        mainPart.data = JSON.stringify(options.body);
    }

    return options.parts;
}