package com.layer7.apim.customassertionplugin.wizards;

import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.wizard.WizardPage;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.ModifyEvent;
import org.eclipse.swt.events.ModifyListener;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.events.SelectionListener;
import org.eclipse.swt.layout.GridData;
import org.eclipse.swt.layout.GridLayout;
import org.eclipse.swt.widgets.Button;
import org.eclipse.swt.widgets.Combo;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Text;

public class CustomAssertionProjectNewWizardPage extends WizardPage {
	
	private Text projectNameText;
	private Text assertionPackageText;
	private Text assertionCodeNameText;
	private Text assertionDisplayNameText;
	private Text assertionDescriptionText;
	private Button includeCustomUI;
	private Combo assertionCategory;
	private Text resultingClasses;
	
	@SuppressWarnings("unused")
	private ISelection selection;

	public CustomAssertionProjectNewWizardPage(ISelection selection) {
		super("wizardPage");
		setTitle("New Layer7 API Management Custom Assertion Project");
		setDescription("This wizard creates a new Layer7 API Management custom assertion project.");
		this.selection = selection;
	}

	public void createControl(Composite parent) {
		Composite container = new Composite(parent, SWT.NULL);
		GridLayout layout = new GridLayout();
		container.setLayout(layout);
		layout.numColumns = 2;
		layout.verticalSpacing = 9;
		
		Label label = new Label(container, SWT.NULL);
		label.setText("Project &Name:");

		projectNameText = new Text(container, SWT.BORDER | SWT.SINGLE);
		GridData gd = new GridData(GridData.FILL_HORIZONTAL);
		projectNameText.setLayoutData(gd);
		projectNameText.addModifyListener(new ModifyListener() {
			public void modifyText(ModifyEvent e) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("Assertion &Package:");

		assertionPackageText = new Text(container, SWT.BORDER | SWT.SINGLE);
		gd = new GridData(GridData.FILL_HORIZONTAL);
		assertionPackageText.setLayoutData(gd);
		assertionPackageText.addModifyListener(new ModifyListener() {
			public void modifyText(ModifyEvent e) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("Assertion &Code Name:");

		assertionCodeNameText = new Text(container, SWT.BORDER | SWT.SINGLE);
		gd = new GridData(GridData.FILL_HORIZONTAL);
		assertionCodeNameText.setLayoutData(gd);
		assertionCodeNameText.addModifyListener(new ModifyListener() {
			public void modifyText(ModifyEvent e) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("Assertion &Display Name:");

		assertionDisplayNameText = new Text(container, SWT.BORDER | SWT.SINGLE);
		gd = new GridData(GridData.FILL_HORIZONTAL);
		assertionDisplayNameText.setLayoutData(gd);
		assertionDisplayNameText.addModifyListener(new ModifyListener() {
			public void modifyText(ModifyEvent e) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("Assertion De&scription:");

		assertionDescriptionText = new Text(container, SWT.BORDER | SWT.SINGLE);
		gd = new GridData(GridData.FILL_HORIZONTAL);
		assertionDescriptionText.setLayoutData(gd);
		assertionDescriptionText.addModifyListener(new ModifyListener() {
			public void modifyText(ModifyEvent e) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("Assertion Cate&gory:");
		
		assertionCategory = new Combo(container, SWT.DROP_DOWN|SWT.READ_ONLY);
		assertionCategory.add("AccessControl");
		assertionCategory.add("TransportLayerSecurity");
		assertionCategory.add("XMLSecurity");
		assertionCategory.add("MessageValidationTransformation");
		assertionCategory.add("MessageRouting");
		assertionCategory.add("ServiceAvailability");
		assertionCategory.add("LoggingAuditingAlerts");
		assertionCategory.add("PolicyLogic");
		assertionCategory.add("ThreatProtection");
		assertionCategory.add("CustomAssertions");
		gd = new GridData(GridData.FILL_HORIZONTAL);
		assertionCategory.setLayoutData(gd);
		assertionCategory.addModifyListener(new ModifyListener() {
			public void modifyText(ModifyEvent e) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("&Include Custom UI:");
		
		includeCustomUI = new Button(container,SWT.CHECK);
		gd = new GridData(GridData.FILL_HORIZONTAL);
		includeCustomUI.setLayoutData(gd);
		includeCustomUI.addSelectionListener(new SelectionListener() {
			public void widgetSelected(SelectionEvent arg0) {
				dialogChanged();
			}
			public void widgetDefaultSelected(SelectionEvent arg0) {
				dialogChanged();
			}
		});
		
		label = new Label(container, SWT.NULL);
		label.setText("Resulting Classes:");

		resultingClasses = new Text(container, SWT.BORDER | SWT.MULTI | SWT.READ_ONLY);
		gd = new GridData(GridData.FILL_BOTH);
		resultingClasses.setLayoutData(gd);
		
		initialize();
		dialogChanged();
		setControl(container);
	}

	private void initialize() {
		projectNameText.setText("SampleProject");
		projectNameText.setFocus();
		assertionPackageText.setText("com.l7tech.custom.sample");
		assertionCodeNameText.setText("Sample");
		assertionDisplayNameText.setText("Apply sample string manipulation");
		assertionDescriptionText.setText("This sample assertion takes two strings as input, converts them to uppercase, and concatenates them. The input strings accept context variables.");
		includeCustomUI.setSelection(false);
		assertionCategory.setText("CustomAssertions");
	}

	private void dialogChanged() {
		
		if (getProjectName().length() == 0) {
			updateStatus("Project name must be specified");
			return;
		}
		if (getAssertionPackage().length() == 0) {
			updateStatus("Assertion package must be specified");
			return;
		}
		if (getAssertionCodeName().length() == 0) {
			updateStatus("Assertion code name must be specified");
			return;
		}
		if (getAssertionDisplayName().length() == 0) {
			updateStatus("Assertion display name must be specified");
			return;
		}

		StringBuilder string = new StringBuilder();

		string.append(getAssertionPackage()+"."+getAssertionCodeName()+"Assertion"+"\n");
		string.append(getAssertionPackage()+"."+getAssertionCodeName()+"ServiceInvocation"+"\n");
		
		if (getIncludeCustomUI()){
			string.append(getAssertionPackage()+"."+getAssertionCodeName()+"UI"+"\n");
			string.append(getAssertionPackage()+"."+getAssertionCodeName()+"Dialog"+"\n");
			string.append("com.l7tech.custom.utilities.ContextVariableUtilities");
		} else {
			string.append("com.l7tech.custom.utilities.ContextVariableUtilities\n");
			string.append("\n");
		}
		


		resultingClasses.setText(string.toString());
		
		updateStatus(null);
	}

	private void updateStatus(String message) {
		setErrorMessage(message);
		setPageComplete(message == null);
	}

	public String getProjectName() {
		return projectNameText.getText();
	}

	public String getAssertionPackage() {
		return assertionPackageText.getText();
	}

	public String getAssertionCodeName() {
		return assertionCodeNameText.getText();
	}

	public String getAssertionDisplayName() {
		return assertionDisplayNameText.getText();
	}

	public String getAssertionDescription() {
		return assertionDescriptionText.getText();
	}
	
	public Boolean getIncludeCustomUI() {
		return includeCustomUI.getSelection();
	}

	public String getAssertionCategory() {
		return assertionCategory.getText();
	}

}