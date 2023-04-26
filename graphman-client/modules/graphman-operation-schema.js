
module.exports = {
    run: function (params) {
        if (params.refresh) {
            require("./graphql-schema").refresh();
        }
    },

    usage: function () {
        console.log("    schema --refresh");
        console.log("        # pre-compiled schema is serialized to schema/metadata.json file");
        console.log("      --refresh");
        console.log("        # to refresh the pre-compiled schema");
    }
}
