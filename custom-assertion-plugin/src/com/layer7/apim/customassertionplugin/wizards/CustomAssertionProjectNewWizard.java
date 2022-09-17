package com.layer7.apim.customassertionplugin.wizards;

import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.eclipse.core.resources.IContainer;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IFolder;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IProjectDescription;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.FileLocator;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.Path;
import org.eclipse.core.runtime.Status;
import org.eclipse.jface.dialogs.MessageDialog;
import org.eclipse.jface.operation.IRunnableWithProgress;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.viewers.IStructuredSelection;
import org.eclipse.jface.wizard.Wizard;
import org.eclipse.ui.INewWizard;
import org.eclipse.ui.IWorkbench;
import org.eclipse.ui.IWorkbenchWizard;
import org.osgi.framework.Bundle;

import com.layer7.apim.customassertionplugin.Activator;


public class CustomAssertionProjectNewWizard extends Wizard implements INewWizard {
	private CustomAssertionProjectNewWizardPage page;
	private ISelection selection;

	/**
	 * Constructor for CustomAssertionProjectNewWizard.
	 */
	public CustomAssertionProjectNewWizard() {
		super();
		setNeedsProgressMonitor(true);
	}
	
	/**
	 * Adding the page to the wizard.
	 */

	public void addPages() {
		page = new CustomAssertionProjectNewWizardPage(selection);
		addPage(page);
	}

	/**
	 * This method is called when 'Finish' button is pressed in
	 * the wizard. We will create an operation and run it
	 * using wizard as execution context.
	 */
	public boolean performFinish() {
		
		final String projectName = page.getProjectName();
		final String assertionPackageName = page.getAssertionPackage();
		final String assertionCodeName = page.getAssertionCodeName();
		final String assertionDisplayName = page.getAssertionDisplayName();
		final String assertionDescription = page.getAssertionDescription();
		final String assertionCategory = page.getAssertionCategory();
		final Boolean includeCustomUI = page.getIncludeCustomUI();
		
		IRunnableWithProgress op = new IRunnableWithProgress() {
			public void run(IProgressMonitor monitor) throws InvocationTargetException {
				try {
					doFinish(projectName, assertionPackageName, assertionCodeName, assertionDisplayName, assertionDescription, assertionCategory, includeCustomUI, monitor);
				} catch (CoreException e) {
					throw new InvocationTargetException(e);
				} finally {
					monitor.done();
				}
			}
		};
		try {
			getContainer().run(true, false, op);
		} catch (InterruptedException e) {
			return false;
		} catch (InvocationTargetException e) {
			Throwable realException = e.getTargetException();
			MessageDialog.openError(getShell(), "Error", realException.getMessage());
			return false;
		}
		return true;
	}
	
	/**
	 * The worker method. It will find the container, create the
	 * file if missing or just replace its contents, and open
	 * the editor on the newly created file.
	 */

	private void doFinish(
		String projectName,
		String assertionPackageName, 
		String assertionCodeName, 
		String assertionDisplayName, 
		String assertionDescription, 
		String assertionCategory, 
		Boolean includeCustomUI,
		IProgressMonitor monitor)
		throws CoreException {
		
		monitor.beginTask("Creating project", 1);
		
        IProject newProject = ResourcesPlugin.getWorkspace().getRoot().getProject(projectName);
         
        if (!newProject.exists()) {
            
        	// Set project location to default workspace location
            IProjectDescription projectDescription = newProject.getWorkspace().newProjectDescription(newProject.getName());
            projectDescription.setLocationURI(null);
            
            // Add Java nature to project
            String[] natures = projectDescription.getNatureIds();
            String[] newNatures = new String[natures.length + 1];
            System.arraycopy(natures, 0, newNatures, 0, natures.length);
            newNatures[natures.length] = "org.eclipse.jdt.core.javanature";
            projectDescription.setNatureIds(newNatures);

            // Create and open the project
            newProject.create(projectDescription, null);
            if (!newProject.isOpen()) {
                newProject.open(null);
            }
            
            // Create project folder structure
            createProjectFolderStructure(newProject, assertionPackageName);
            
            // Create project files
            createProjectFiles(newProject, assertionPackageName, assertionCodeName, assertionDisplayName, assertionDescription, assertionCategory, includeCustomUI);
           			
        } else {
        	throwCoreException("A project with this name already exists.");
        }
        
		monitor.worked(1);
	}
	
	private void createProjectFiles(IProject newProject,
			String assertionPackageName, String assertionCodeName,
			String assertionDisplayName, String assertionDescription,
			String assertionCategory, Boolean includeCustomUI) throws CoreException {
		
		IContainer rootFolder = newProject;
		IContainer libFolder = (IContainer)newProject.getFolder("lib");
		IContainer resourcesFolder = (IContainer)newProject.getFolder("resources");
		IContainer assertionSourceFolder = (IContainer)newProject.getFolder(getPackageSourcePath(assertionPackageName));
		
		// Copy layer7-api-8.11.01.jar to lib folder
		copyFile("resources/layer7-api-8.11.01.jar", libFolder, "layer7-api-8.11.01.jar");

		// Copy classpath file to root folder
		copyFile("resources/classpath.xml", rootFolder, ".classpath");

		// Create ant build file
		String buildFile = readPluginBundleFileAsString("resources/build.xml");

		Pattern pattern = Pattern.compile("\\$assertionCodeName\\$");
        Matcher matcher = pattern.matcher(buildFile);
        buildFile = matcher.replaceAll(assertionCodeName);
     
        createFile(rootFolder, "build.xml", buildFile);

		// Create custom assertion properties file
		String customAssertionProperties = readPluginBundleFileAsString("resources/custom_assertions.properties");
		
		pattern = Pattern.compile("\\$assertionPackageName\\$");
        matcher = pattern.matcher(customAssertionProperties);
        customAssertionProperties = matcher.replaceAll(assertionPackageName);
        
		pattern = Pattern.compile("\\$assertionCodeName\\$");
        matcher = pattern.matcher(customAssertionProperties);
        customAssertionProperties = matcher.replaceAll(assertionCodeName);

		pattern = Pattern.compile("\\$assertionCategory\\$");
        matcher = pattern.matcher(customAssertionProperties);
        customAssertionProperties = matcher.replaceAll(assertionCategory);
        
		pattern = Pattern.compile("\\$assertionDescription\\$");
        matcher = pattern.matcher(customAssertionProperties);
        customAssertionProperties = matcher.replaceAll(assertionDescription);
        
        if (!includeCustomUI) {
    		pattern = Pattern.compile("^.*\\.ui\\=.*$", Pattern.MULTILINE);
            matcher = pattern.matcher(customAssertionProperties);
            customAssertionProperties = matcher.replaceAll("");        	
        }
        
        createFile(resourcesFolder, "custom_assertions.properties", customAssertionProperties);

		// Create Assertion class file
		String assertionClassTemplate = readPluginBundleFileAsString("resources/SampleAssertion.template");
		
		pattern = Pattern.compile("\\$assertionPackageName\\$");
        matcher = pattern.matcher(assertionClassTemplate);
        assertionClassTemplate = matcher.replaceAll(assertionPackageName);
        
		pattern = Pattern.compile("\\$assertionCodeName\\$");
        matcher = pattern.matcher(assertionClassTemplate);
        assertionClassTemplate = matcher.replaceAll(assertionCodeName);

		pattern = Pattern.compile("\\$assertionDisplayName\\$");
        matcher = pattern.matcher(assertionClassTemplate);
        assertionClassTemplate = matcher.replaceAll(assertionDisplayName);
        
        createFile(assertionSourceFolder, assertionCodeName+"Assertion.java", assertionClassTemplate);
        
        // Create ServiceInvocation class file
		String serviceInvocationClassTemplate = readPluginBundleFileAsString("resources/SampleServiceInvocation.template");
		
		pattern = Pattern.compile("\\$assertionPackageName\\$");
        matcher = pattern.matcher(serviceInvocationClassTemplate);
        serviceInvocationClassTemplate = matcher.replaceAll(assertionPackageName);
        
		pattern = Pattern.compile("\\$assertionCodeName\\$");
        matcher = pattern.matcher(serviceInvocationClassTemplate);
        serviceInvocationClassTemplate = matcher.replaceAll(assertionCodeName);

        createFile(assertionSourceFolder, assertionCodeName+"ServiceInvocation.java", serviceInvocationClassTemplate);

		if (includeCustomUI) {
			
			// Create UI class file
			String uiClassTemplate = readPluginBundleFileAsString("resources/SampleUI.template");
			
			pattern = Pattern.compile("\\$assertionPackageName\\$");
	        matcher = pattern.matcher(uiClassTemplate);
	        uiClassTemplate = matcher.replaceAll(assertionPackageName);
	        
			pattern = Pattern.compile("\\$assertionCodeName\\$");
	        matcher = pattern.matcher(uiClassTemplate);
	        uiClassTemplate = matcher.replaceAll(assertionCodeName);
	        
	        createFile(assertionSourceFolder, assertionCodeName+"UI.java", uiClassTemplate);

			// Create Dialog class file
			String dialogClassTemplate = readPluginBundleFileAsString("resources/SampleDialog.template");
			
			pattern = Pattern.compile("\\$assertionPackageName\\$");
	        matcher = pattern.matcher(dialogClassTemplate);
	        dialogClassTemplate = matcher.replaceAll(assertionPackageName);
	        
			pattern = Pattern.compile("\\$assertionCodeName\\$");
	        matcher = pattern.matcher(dialogClassTemplate);
	        dialogClassTemplate = matcher.replaceAll(assertionCodeName);

			pattern = Pattern.compile("\\$assertionDisplayName\\$");
	        matcher = pattern.matcher(dialogClassTemplate);
	        dialogClassTemplate = matcher.replaceAll(assertionDisplayName);

	        createFile(assertionSourceFolder, assertionCodeName+"Dialog.java", dialogClassTemplate);

		}

	}

	private void copyFile(String bundleFilePath, IContainer destinationFolder, String destinationFileName) throws CoreException {
		
		InputStream apiInputStream = getPluginBundleInputStream(bundleFilePath);
		IFile file = destinationFolder.getFile(new Path(destinationFileName));
		file.create(apiInputStream, true, null);
		try {
			apiInputStream.close();
		} catch (IOException e) {
			throwCoreException("IOException when trying to copy bundle file, " + bundleFilePath + " to " + destinationFolder.getFullPath().toString() + "/" + destinationFileName + ": " + e.getMessage());
		}
		
	}

	private void createFile(IContainer folder, String fileName, String fileContents) throws CoreException {

		IFile file = folder.getFile(new Path(fileName));
		ByteArrayInputStream stream = new ByteArrayInputStream(fileContents.getBytes());
		file.create(stream, true, null);
		
	}

	private void createProjectFolderStructure(IProject newProject, String assertionPackageName)  throws CoreException {
        
        // Create assertion package folders
        IFolder folder = newProject.getFolder(getPackageSourcePath(assertionPackageName));
        createFolder(folder);
        
        // Create lib folder
        folder = newProject.getFolder("lib");
        createFolder(folder);
        
        // Create resources folder
        folder = newProject.getFolder("resources");
        createFolder(folder);

	}

	private String getPackageSourcePath(String packageName) {
		Pattern pattern = Pattern.compile("\\.");
        Matcher matcher = pattern.matcher(packageName);
        return "src/" + matcher.replaceAll("/");
	}
	
	private void createFolder(IFolder folder) throws CoreException {
		IContainer parent = folder.getParent();
		if (parent instanceof IFolder) {
			createFolder((IFolder) parent);
		}
		if (!folder.exists()) {
			folder.create(false, true, null);
		}
	}
	
	private String readPluginBundleFileAsString(String filePath) throws CoreException {
                
        BufferedInputStream in = new BufferedInputStream(getPluginBundleInputStream(filePath));
        ByteArrayOutputStream out = new ByteArrayOutputStream();
    
        int result = -1;
        
        do{
        	try {
				result = in.read();
			} catch (IOException e) {
				throwCoreException("IOException reading file: " + filePath);
			}
        	if (result != -1){
                byte b = (byte)result;
                out.write(b);
        	}        	
        }while (result != -1);
        	
        return out.toString();
        
	}

	private InputStream getPluginBundleInputStream(String filePath) throws CoreException {
        
		Activator plugin = Activator.getDefault();
        Bundle bundle = plugin.getBundle();
        Path path = new Path(filePath);
        
		try {
			return FileLocator.openStream(bundle, path, false);
		} catch (IOException e) {
			throwCoreException("IOException opening bundle file input stream: " + filePath);
		}
		
		return null;
	}
	
	private void throwCoreException(String message) throws CoreException {
		IStatus status =
			new Status(IStatus.ERROR, "Layer7_APIM_CustomAssertionPlugin", IStatus.OK, message, null);
		throw new CoreException(status);
	}

	/**
	 * We will accept the selection in the workbench to see if
	 * we can initialize from it.
	 * @see IWorkbenchWizard#init(IWorkbench, IStructuredSelection)
	 */
	public void init(IWorkbench workbench, IStructuredSelection selection) {
		this.selection = selection;
	}
}