
# GCI-MDE-AutoTag

## Microsoft Defender for Endpoint - Automated Group Tagging Utility

This PowerShell script automates the process of applying tags to devices in **Microsoft Defender for Endpoint (MDE)** based on **Azure AD/Entra ID group** membership. It fills a critical gap in Microsoft's native functionality, which currently only supports tagging based on OS type and naming conventions.

---

## 🚀 Why This Tool Exists

Microsoft Defender for Endpoint offers powerful tagging capabilities but lacks a built-in method to apply tags based on dynamic group membership. This script is useful when:

- Devices don’t follow a consistent naming convention  
- Tags must be applied across different operating systems  
- Existing Entra ID groups are in use for segmentation  

This tool bridges the gap by leveraging Entra ID group membership for consistent device tagging in MDE.

---

## 🔧 Features

- Secure, interactive authentication with Microsoft Graph and MDE APIs  
- Auto-discovery of devices in a specified Entra ID group  
- Device matching between Entra ID and MDE  
- Bulk tagging in a single operation  
- Reporting of successful/failed tagging actions  
- Generates KQL exclusion queries for advanced hunting  

---

## 📋 Prerequisites

- **PowerShell 5.1 or higher**  
- Permissions for:  
  - Microsoft Graph API  
  - Microsoft Defender for Endpoint API  
- Required PowerShell modules (auto-installed if missing):  
  - `Microsoft.Graph.Authentication`  
  - `Microsoft.Graph.Groups`  
  - `Microsoft.Graph.Identity.DirectoryManagement`  
  - `MSAL.PS`  

---

## ▶️ Usage

```powershell
.\GCI-MDE-AutoTag.ps1 -GroupId "YOUR-GROUP-ID-HERE" -TagName "YOUR-TAG-NAME-HERE"
````

---

## 📌 Parameters

* **GroupId**: The ID of the Entra ID group containing the devices to tag
* **TagName**: The tag to apply in Microsoft Defender for Endpoint

---

## 📘 Step-by-Step Guide

1. **Download the Script**

   * Save `GCI-MDE-AutoTag.ps1` to your local machine

2. **Open PowerShell**

   * Run as Administrator

3. **Execute the Script**

   ```powershell
   .\GCI-MDE-AutoTag.ps1 -GroupId "YOUR-GROUP-ID-HERE" -TagName "YOUR-TAG-NAME-HERE"
   ```

4. **Authenticate**

   * The script will prompt you to sign in to Microsoft Graph and Defender for Endpoint interactively

5. **Review and Confirm**

   * A summary of devices to be tagged will be displayed
   * You'll be asked to confirm before proceeding

---

## 🔍 KQL Query for Tagged Devices

Use this query in **Microsoft Defender for Endpoint** or **Microsoft Sentinel** to find tagged devices:

```kql
DeviceDynamicTags contains "YOUR-TAG-NAME-HERE"
or RegistryDeviceTag contains "YOUR-TAG-NAME-HERE"
or DeviceManualTags contains "YOUR-TAG-NAME-HERE"
```

---

## 💡 Use Cases

* Create device exception lists for security policies based on organizational structure
* Tag approved devices to exclude them from specific detection rules
* Implement role-based access controls (RBAC) in Microsoft Defender for Endpoint
* Automate security operations workflows for device classification
* Support compliance requirements by properly tagging regulated devices

---

## 📤 Output

* Provides detailed feedback during execution
* Lists successfully and unsuccessfully tagged devices

---

## 👨‍💻 Author

**Goodness Caleb Ibeh**
[LinkedIn](https://linkedin.com/caleb-ibeh)

```

