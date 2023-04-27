
const utils = require("./graphman-utils");
const SCHEMA_DIR = utils.home() + "/schema";
const SCHEMA_METADATA_BASE_FILE = SCHEMA_DIR + "/metadata-base.json";
const SCHEMA_METADATA_FILE = SCHEMA_DIR + "/metadata.json";
let SCHEMA_METADATA = null;

module.exports = {
    metadata: function () {
      if (!SCHEMA_METADATA) {
          SCHEMA_METADATA = utils.existsFile(SCHEMA_METADATA_FILE) ?
              utils.readFile(SCHEMA_METADATA_FILE) : build();
      }

      return SCHEMA_METADATA;
    },

    refresh: function () {
        build();
        utils.info("pre-compiled schema is refreshed");
    }
};

function build() {
    const metadata = utils.readFile(SCHEMA_METADATA_BASE_FILE);

    // start parsing the graphql schema files
    utils.listDir(SCHEMA_DIR).forEach(file => {
        if (file.endsWith(".graphql")) {
            parseSchemaFile(SCHEMA_DIR + "/" + file, metadata);
        }
    });


    Object.entries(metadata.types).forEach(([key, value]) => {
        // to retrieve type using its plural method
        metadata.pluralMethods[value.pluralMethod] = key;

        // define summary fields
        if (!value.summaryFields || !Array.isArray(value.summaryFields) || value.summaryFields.length === 0) {
            const sFields = value.summaryFields = ["goid"];
            if (value.fields.includes("guid")) sFields.push("guid");
            if (value.idFields) value.idFields.forEach(item => sFields.push(item));
            else if (value.idField) sFields.push(value.idField);
            sFields.push("checksum");
        }

        // restore the enum type fields
        value.fields.forEach((field, index) => {
            const tokens = field.split(/[{}]/); // <field-name> { {{<field-type>}} }
            if (tokens && metadata.enumTypes.includes(tokens[3])) {
                value.fields[index] = tokens[0];
            }
        });
    });

    utils.writeFile(SCHEMA_METADATA_FILE, metadata);
    return metadata;
}

function parseSchemaFile(file, metadata) {
    const lines = utils.readFile(file).split(/\r?\n/);
    let obj = null;
    let multilineComment = false;

    for (var line of lines) {
        if (line.match(/^\s*"""/)) {
            multilineComment = !multilineComment;
            continue;
        }

        if (multilineComment || line.match(/^\s*"/) || line.match(/^\s*#/)) {
            continue;
        }

        if (!obj) {
            const match = line.match(/(type|enum)\s+(\w+)/);
            const typeType = match ? match[1] : null;
            const typeName = match ? match[2] : null;
            if (typeType === 'enum') {
                metadata.enumTypes.push(typeName);
            } else if (typeType === 'type') {
                obj = metadata.types[typeName];
                if (!obj) obj = metadata.types[typeName] = {};
                if (!obj.fields) obj.fields = [];
                if (!obj.summaryFields) obj.summaryFields = [];
            }
        } else {
            const match = line.match(/\s+(\w+)\s*[:]\s*[\[]?(\w+)/); // field declaration, <field-name>: <field-type>
            const fieldName = match ? match[1] : null;
            const fieldType = match ? match[2] : null;

            if (fieldName) {
                if (fieldType && !metadata.parserHints.excludedDataTypes.includes(fieldType)) {
                    if (metadata.parserHints.excludedFields[fieldType]) {
                        obj.fields.push(fieldName + "{ {{" + fieldType + ":-" + metadata.parserHints.excludedFields[fieldType] + "}} }");
                    } else {
                        obj.fields.push(fieldName + "{ {{" + fieldType + "}} }");
                    }
                } else {
                    obj.fields.push(fieldName);
                }
            }

            if (line.indexOf('}') !== -1) { // type definition ends
                obj = null;
            }
        }
    }
}
