# Layer7 API Management Custom Assertion Plugin for Eclipse
This folder contains the source for an Eclipse plug-in project to build the Layer7 API Management Custom Assertion Plugin for Eclipse.

The Layer7 API Management Custom Assertion Plugin makes it very quick and easy to build new custom assertions for the Layer7 API Gateway using the Eclipse IDE.

## Installing the plugin

A recent build of the plugin including the layer7-api-8.11.01.jar custom assertion SDK library can be found in the export folder [here](export/plugins/Layer7_APIM_CustomAssertionPlugin_4.0.0.0.jar). Download this file and place it in the dropins folder inside your Eclipse installation folder, and then restart Eclipse.

For example, on a Mac:

![dropin-folder.png](/images/dropin-folder.png)

## Using the plugin

In Eclipse, create a new project:

![new-project.png](/images/new-project.png)

Select the Layer7 API Management Custom Assertion Project wizard:

![select-wizard.png](/images/select-wizard.png)

Change any of the project values as desired. These values will be used together with code templates when your custom assertion project is created. They can always be changed later in the code. The default values will result in a custom assertion that can be immediately built and deployed to your Layer7 API Gateway. This custom assertion takes two strings as input, converts them to upper case, concatenates them and returns the result as an output string in policy. Its reasonable well documented code demonstrates other concepts related to custom assertion development too.

![project-config.png](/images/project-config.png)

Build your custom assertion by right clicking the build.xml file in the root folder of your project, and select Run As -> Ant Build:

![ant-build.png](/images/ant-build.png)

> Note: Any third party libraries required by your custom assertion can be put in the `/lib` folder in your custom assertion project. These will be included in the custom assertion .jar file and available on the gateway when needed.

A successful build will appear similar to this in your Eclipse console:

![build-result.png](/images/build-result.png)

Upload the .jar file from the `/build` folder in your custom assertion project to `/opt/SecureSpan/Gateway/runtime/modules/lib/` on your API Gateway, and change its ownership to `layer7:Layer7`.

Restart your gateway, and refresh Policy Manager.

Find and use your new custom assertion in the Policy Manager assertion palette

![build-result.png](/images/policy-manager.png)

> Note: By default, your custom assertion appear under the Custom Assertion folder in the assertion palette, and will have a standard dialog for configuring assertion properties. These things can be changed in the Layer7 API Management Custom Assertion Project wizard and the custom assertion code.

## Enhancing the plugin

If you want to modify the plugin itself, you may want to start with the [Eclipse IDE for RCP and RAP Developer](https://www.eclipse.org/downloads/packages/release/2022-09/r/eclipse-ide-rcp-and-rap-developers). It contains the necessary components for Eclipse plugin development.