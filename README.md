Azure Logic App for Automated Carbon Emissions Data Export
Overview of the Solution
This solution uses an Azure Logic App to automatically extract Azure Carbon Optimization emissions data on a monthly schedule and save it as CSV files in Azure Blob Storage. The goal is to replicate the Azure Portal’s “Export to CSV” for carbon emissions, providing both a subscription-level emissions report (latest and previous month) and a monthly trends report (12-month emissions trend with scope breakdown). The workflow is as follows:
Monthly Trigger: A recurrence trigger (e.g. on the 19th of each month, after data is published
learn.microsoft.com
) initiates the Logic App.
Data Availability Check: (Optional) The Logic App calls the “Query Carbon Emission Data Available Date Range” REST API to ensure the last month’s data is available
articles.xebia.com
. This prevents running before the latest emissions data is published (usually by the 19th of the month for the previous month’s data
learn.microsoft.com
).
Call Emissions APIs: Using HTTP actions, the Logic App invokes the “Query Carbon Emission Reports” REST API to fetch:
Subscription Emissions Detail: carbon emissions for each target subscription, including the latest month and previous month values (mirroring the portal’s Emission Details table).
Monthly Emissions Trend: total emissions per month (with Scope 1, 2, 3 breakdown and carbon intensity) for the last 12 months (mirroring the portal’s Emission Trends chart).
Convert JSON to CSV: The JSON response from each API call is transformed into CSV format. The Logic App can use a Data Operations – Create CSV table action to convert an array of JSON objects into CSV text with a header row. The CSV schema matches the portal export format (e.g. columns Subscription_Name, Subscription_Id, Latest_Month_Emissions_kgCO2E, Previous_Month_Emissions_kgCO2E for subscription detail
file-p9byqvrn4xq64jfg8njquh
, and Month, TotalEmissions, Scope1, Scope2, Scope3, CarbonIntensity for trends
file-76pvotbmw8nmdyi2udax8f
).
Blob Storage Upload: The Logic App writes the CSV content to an Azure Blob Storage container (e.g. in a folder or container for emissions exports). Filenames can include a timestamp or month (for example, EmissionDetails-Subscriptions-2025-04.csv and EmissionTrends-2025-04.csv for an April 2025 data export).
Notification/Logging (Optional): The Logic App can send a notification (email/Teams) on success or failure, and output logging information for monitoring.
This automation ensures a consistent, auditable record of Azure carbon emissions data. IT or sustainability teams can use the exported CSVs for reporting, integration with other tools, or historical analysis beyond the portal’s 2-month UI limit
learn.microsoft.com
. All credentials are managed via Azure Managed Identity (no hard-coded secrets), and the solution is deployed and configured through infrastructure-as-code for repeatability.
API Details
Azure Carbon Optimization REST APIs provide programmatic access to emissions data (the same data shown in the Azure Portal’s Carbon Optimization pages
github.com
). Key endpoints used in this solution include:
Query Carbon Emission Data Available Date Range:
Method & URL: POST https://management.azure.com/providers/Microsoft.Carbon/queryCarbonEmissionDataAvailableDateRange?api-version=2025-04-01
Purpose: Returns the date range of available emissions data. This helps determine the earliest and latest month for which data is available
articles.xebia.com
articles.xebia.com
. The response includes startDate and endDate (e.g., "startDate": "2022-02-01", "endDate": "2024-01-01"
articles.xebia.com
), indicating that data is available from Feb 2022 up to Jan 2024 in that example. The Logic App can use this to confirm that the previous month’s data is ready (the endDate should equal the first day of last month, since data is published monthly). If the latest month isn’t yet available, the Logic App could delay execution or simply exit and retry later (based on scheduling or a retry policy).
Query Carbon Emission Reports:
Method & URL: POST https://management.azure.com/providers/Microsoft.Carbon/carbonEmissionReports?api-version=2025-04-01
Purpose: Retrieves the actual emissions data reports in JSON format
learn.microsoft.com
. This is a versatile API that, based on the request body, can return different report types (similar to selecting different views in the portal). The request body must include a JSON payload specifying the report parameters. Key parameters include:
reportType: The type of report to generate. Relevant values are:
ItemDetailReport – Detailed emissions for a specific category (e.g. by Subscription, Resource Group, Resource, Resource Type, or Location). This is used for subscription-level data export (and can also drill down to resource level if needed).
MonthlySummaryReport – Emissions broken down by month over a date range (used for the 12-month trend export).
(Other types like OverallSummaryReport, TopItemsSummaryReport, etc., exist but are not required for this scenario
learn.microsoft.com
learn.microsoft.com
).
subscriptionList: Array of Azure subscription IDs to include
dannyvanderkraan.wordpress.com
. The API will return data for these subscriptions (the identity must have access, see Authentication section). You can specify multiple subscriptions here, or just one, depending on requirements.
carbonScopeList: Array of emission scopes to include
learn.microsoft.com
. Valid values are “Scope1”, “Scope2”, “Scope3”. Typically, to get complete emissions, all scopes are included. In Azure’s carbon accounting, Scope 3 covers the indirect emissions from your Azure usage (often the main value for customers), while Scope 1 and 2 might be zero for most Azure services (as seen in the portal exports where Scope1/2 columns are often 0
file-76pvotbmw8nmdyi2udax8f
). Including all ensures the TotalEmissions reflects full footprint.
dateRange: The start and end dates (inclusive) for the data query
learn.microsoft.com
. Dates must be given in YYYY-MM-01 format (first day of the month). For MonthlySummaryReport, the range can span multiple months (up to 12 months of data, per API limits
learn.microsoft.com
). For ItemDetailReport, only a single month is supported (the start and end should be the same month)
learn.microsoft.com
. Typically, to get last month’s detail, set both start and end to the first day of the last month (e.g., start = 2025-04-01 and end = 2025-04-01 to retrieve data for April 2025).
categoryType: (For ItemDetailReport) the category of item for breakdown
learn.microsoft.com
. For example, "Subscription" will return one entry per subscription, "Resource" returns per resource, "ResourceGroup", "ResourceType", or "Location" are also supported
learn.microsoft.com
. In our case, to mimic the portal’s Emission Details by subscription, we use "Subscription".
Other optional parameters: sortDirection (Asc or Desc), orderBy (e.g. totalCarbonEmission or itemName etc.), pageSize, and skipToken for pagination
github.com
dannyvanderkraan.wordpress.com
. By default, the API might return up to 100 items; to ensure all subscriptions are retrieved if you have many, you can set a large pageSize (the portal uses 100 by default
learn.microsoft.com
). If the result is paginated, a skipToken will be returned for fetching the next page. The Logic App should handle this by looping if skipToken is not empty (though in most cases for subscription-level data, 100 items per page is sufficient).
Example Request: Below is a sample JSON body for the carbonEmissionReports API. It requests an ItemDetailReport for a specific month and subscriptions, including all emission scopes (the example shows categoryType “Resource”, but for subscription-level data we would use "Subscription" instead):
{
  "reportType": "ItemDetailsReport",
  "groupCategory": "",
  "subscriptionList": [ "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" ],
  "resourceGroupUrlList": [],
  "carbonScopeList": [ "Scope1", "Scope2", "Scope3" ],
  "dateRange": { "start": "2024-04-01", "end": "2024-04-01" },
  "categoryType": "Resource",
  "sortDirection": "Desc",
  "pageSize": 2000,
  "orderBy": "totalCarbonEmission"
}
github.com
github.com
 (In this sample, categoryType is “Resource” and a specific subscription is listed. In the actual Logic App for subscription summaries, categoryType would be set to “Subscription”. Other fields can be adjusted or left blank as above. The orderBy and sortDirection ensure the results are sorted by highest emissions, which is useful for reporting.) Example Responses: The API returns JSON data. For ItemDetailReport with categoryType: Subscription, each element in the value array corresponds to one subscription’s emissions for the month. Key fields include: subscriptionId, itemName (which is the Subscription Name in this context), totalCarbonEmission (emissions for the queried month, in kgCO2e), and totalCarbonEmissionLastMonth (emissions for the month prior)
github.com
github.com
, as well as percentage or absolute changes (changeRatioForLastMonth, etc.). The Logic App will map these to CSV columns Subscription_Name, Subscription_Id, Latest_Month_Emissions_kgCO2E and Previous_Month_Emissions_kgCO2E respectively
file-p9byqvrn4xq64jfg8njquh
. For MonthlySummaryReport, the response value array contains one entry per month in the range, with fields like date (month), latestMonthEmissions (emissions that month), previousMonthEmissions (prior month’s emissions), and carbonIntensity (average carbon intensity in gCO2 per kWh)
learn.microsoft.com
. The Logic App will map these to columns Month, TotalEmissions, Scope1, Scope2, Scope3, CarbonIntensity
file-76pvotbmw8nmdyi2udax8f
. In practice, when all scopes are requested together, latestMonthEmissions represents the total emissions (Scope1+2+3) for that month. The breakdown by scope can be derived by running separate queries per scope or (if available) by parsing deeper data, but since the portal CSV itself lists Scope1/2/3 separately, the likely approach is to call the API once per scope or use another report type. However, to keep things simple, this solution assumes total emissions are primarily scope3 and uses total for reporting (scope columns can be left at 0 if not separately fetched, matching portal behavior where Scope1/2 are often zero
file-76pvotbmw8nmdyi2udax8f
). Required Headers & Auth: Both APIs are part of the ARM (Azure Resource Manager) endpoint (management.azure.com) and use Azure AD OAuth2 for auth
learn.microsoft.com
. The Logic App must attach an Authorization: Bearer <token> header with a valid token for the Azure Management audience
articles.xebia.com
. In our solution, the Logic App’s Managed Identity will acquire this token automatically (see Authentication below). The HTTP actions in the Logic App will also specify Content-Type: application/json for the POST body. No other special headers are required for these API calls. Using the APIs in a Logic App: In summary, the Logic App will perform two POST calls to carbonEmissionReports: one for the subscription itemized report (with reportType: ItemDetailsReport, categoryType: Subscription, dateRange = last month) and one for the monthly trend report (reportType: MonthlySummaryReport, dateRange = last 12 months). For example, using Azure CLI for illustration, one could retrieve a 12-month summary with a command like:
az carbon get-emission-report --subscription-list "[SUBSCRIPTION_ID]" \
  --carbon-scope-list "[Scope1,Scope2,Scope3]" \
  --date-range "{start:2024-05-01,end:2025-04-01}" \
  --monthly-summary
which would return monthly data from May 2024 through April 2025
learn.microsoft.com
. The Logic App will do the equivalent via an HTTP POST with the appropriate JSON payload.
Authentication (Managed Identity & Permissions)
The Logic App uses a Managed Identity (system-assigned) to authenticate to Azure APIs, avoiding any hard-coded credentials. The managed identity acts as a service principal that must be granted access to the Carbon Optimization data and to the storage account:
Azure Carbon API Access: The managed identity needs at least read-level permission to Carbon Optimization emissions data. Azure uses role-based access control (RBAC) for Carbon Optimization. By default, Subscription Reader/Contributor/Owner roles already include the ability to view emissions data
learn.microsoft.com
. For least privilege, Azure provides a built-in Carbon Optimization Reader role, which “allows read access to Azure Carbon Optimization data”
azadvertizer.net
. We recommend assigning this role to the Logic App’s identity on each subscription that will be queried. For example, if the Logic App will pull data for Subscription A and B, grant its identity the Carbon Optimization Reader role on those subscriptions. This role can be assigned via Access Control (IAM) in the Azure Portal or via template (see Deployment Plan). Once in place, the Logic App can call the carbon APIs without issue (the Carbon service will authorize the token against these RBAC settings). If for some reason the identity cannot be given this role, any role that grants Reader access to the subscription (or higher) would also work, since Readers can view emissions data by default
learn.microsoft.com
. Note: Ensure that the Microsoft.Carbon resource provider is enabled in the subscription (in preview, this may require registration or that the feature wasn’t disabled by an admin). Typically, accessing the Carbon Optimization blade or API the first time will auto-register the provider if needed. Also, the tenant’s Azure Carbon Optimization application must be enabled (it is by default; only an issue if an administrator manually turned it off)
learn.microsoft.com
.
Azure Blob Storage Access: The Logic App’s identity also needs permission to write to the storage container. We use Azure AD authentication for Blob Storage rather than storage keys. Assign the Storage Blob Data Contributor role to the Logic App’s managed identity for the target storage account (at the resource or container scope)
learn.microsoft.com
. This role allows creating and overwriting blob files. After assignment, the Logic App can use its identity to call blob operations (either via the Azure Blob connector or direct REST calls) securely.
Once these roles are in place, the Logic App’s HTTP actions can use Managed Identity authentication. In the Logic App Designer, the HTTP action’s Authentication section is set to use “Managed Identity”, with Audience or Resource = https://management.azure.com/ (for the carbon API calls). This instructs the Logic App to obtain a token for the ARM API using its identity and attach it to the request
articles.xebia.com
. Similarly, for the Blob storage actions, if using the Azure Blob Storage connector, we configure it to use the system-assigned managed identity (the connector will handle token acquisition for Azure Storage). This way, all API calls are authenticated without any stored credentials. Azure RBAC Roles Summary:
Carbon Optimization Reader on subscription (or Reader/Contributor/Owner) – to allow querying emissions
learn.microsoft.com
.
Storage Blob Data Contributor on the storage account – to allow writing CSV files to Blob
learn.microsoft.com
.
No explicit Azure AD App Registration or client secret is required – the Logic App’s identity handles it. This also means no “secrets” are present in the solution, and access can be revoked by removing the roles or disabling the identity as needed.
Blob Storage Integration
For storing the output CSV, the solution uses an Azure Blob Storage container. The Logic App will create or overwrite blobs (CSV files) in a specified container each month. Key design points for blob integration:
Storage Account & Container: You can use an existing storage account or deploy a new one for this solution. A container (e.g., “carbon-emissions-reports”) will hold the CSV files. The container name and storage account can be provided as parameters in the deployment. Ensure that the storage account allows access from the Logic App (if using networking restrictions, you may need to enable a trusted Azure services exception or integrate the Logic App with a VNet if applicable – out of scope for this design but worth noting if locked down environment).
Writing the CSV: The Logic App uses either an Azure Blob Storage connector action or a generic HTTP call to the Blob REST API. The simplest method is to use the built-in Azure Blob connector (available in Logic Apps Standard or via an API connection in Consumption). There is an action “Create blob” (or “Create file”) where we specify the storage account, container, blob name, and file content. Since we configured the connector to use the managed identity, no further auth is needed – the Logic App will use its identity to authorize the blob write
learn.microsoft.com
. If using an HTTP action instead (for example, if fine-grained control is needed or to avoid creating a separate connection resource), the Logic App can call the Azure Storage Blob REST API. In that case, it would perform a PUT request to the blob’s URL (e.g., https://<account>.blob.core.windows.net/<container>/<filename>) with the CSV text in the body. The Logic App’s managed identity can be used to get an access token for https://storage.azure.com/ and set it in the Authorization header. However, this is more complex to set up manually. Using the Blob connector abstracts these details, so the recommended approach is to use the “Create Blob” action with managed identity.
Blob Naming Convention: We can name files to easily identify the reporting period. For example:
EmissionDetails-Subscription-{MonthYear}.csv – e.g. EmissionDetails-Subscription-Apr2025.csv
file-p9byqvrn4xq64jfg8njquh
, containing the subscription emissions for March 2025 as the latest month (the file is labeled Apr 2025 since that is when data became available).
EmissionTrends-{MonthYear}.csv – e.g. EmissionTrends-Apr2025.csv
file-76pvotbmw8nmdyi2udax8f
, containing month-by-month emissions up through April 2025.
The Logic App can construct the blob name dynamically. For instance, after determining the “latest available month” (say April 2025), it can format a string “Apr2025” for the filename. This can be derived from the date (using an Azure Function or Logic App expression to get a month abbreviation and year).
Content Format: The CSV content is plain text. We should include a header row matching the portal export. For subscription details, the header is:
"Subscription_Name","Subscription_Id","Latest_Month_Emissions_kgCO2E","Previous_Month_Emissions_kgCO2E"
file-p9byqvrn4xq64jfg8njquh
.
For trends:
"Month","TotalEmissions","Scope1","Scope2","Scope3","CarbonIntensity"
file-76pvotbmw8nmdyi2udax8f
.
The Logic App’s Create CSV table action can generate these headers automatically if the JSON is parsed (the property names become headers). We may need to adjust the names since the JSON field totalCarbonEmission would yield “totalCarbonEmission” as a header by default. We can either rename the JSON properties (using a Select or Compose step to map to desired names) before creating the CSV, or use the action’s advanced options to specify custom column names. For example, map itemName -> “Subscription_Name”, subscriptionId -> “Subscription_Id”, totalCarbonEmission -> “Latest_Month_Emissions_kgCO2E”, and totalCarbonEmissionLastMonth -> “Previous_Month_Emissions_kgCO2E” for the subscription CSV. Similarly, for the trend CSV, map the monthly data fields to the corresponding scope columns (if separate scope data is obtained).
Verification: After the Logic App runs, the CSV files can be opened to verify format. They should closely mirror the portal exports the user provided (the examples given show the expected format and units). Each run of the Logic App will produce new CSVs (or update existing ones). Old files can be retained for archive or overwritten if only the latest is needed – this is configurable in the workflow (e.g., include month in filename to keep history, or use a fixed name like “LatestEmissionDetails.csv” to always overwrite).
By leveraging Azure Blob Storage with RBAC, we ensure data is securely stored (we can optionally enable soft delete or snapshots on the container for protection). The CSV files in Blob can be accessed by authorized users or services (e.g., downloaded for analysis, or ingested into Power BI, etc.).
Logic App Design
This section outlines the Logic App workflow in detail, including trigger configuration and each step in the process:
Trigger – Recurrence (Monthly): The Logic App is configured to run on a schedule. Using a Recurrence trigger, we set it to Monthly on a specific day and time. For example, run on the 20th of each month at 00:00 UTC. This ensures the previous month’s emissions are available (as discussed, data for the prior month is typically published by the 19th
learn.microsoft.com
). The schedule and timezone can be adjusted as needed. (If finer control is needed, one could also use a combination of a shorter recurrence with a condition to check for data availability, but a simple monthly schedule is sufficient given the predictable release cycle.)
Initialize Variables (optional): We might use variables to store intermediate values like the target year-month string for filenames or a list of subscription IDs. For instance, determine latestMonth = endDate from the data range API, then format “MMMYYYY” for file naming. Another variable could hold the array of subscription IDs if not hard-coded.
Step 1: (Optional) Get Available Date Range: An HTTP POST action calls the queryCarbonEmissionDataAvailableDateRange endpoint
articles.xebia.com
. No body is needed for this call. We use Managed Identity authentication (as described in Authentication) so the Logic App will attach the bearer token. The response (JSON) will contain startDate and endDate. We parse this JSON (using a Parse JSON action or direct expressions) to retrieve endDate. If the Logic App needs to ensure it only proceeds when data is fresh, it can compare endDate to the expected last month. For example, if today is June 20, 2025, we expect endDate to be 2025-05-01. If it is still 2025-04-01, that means May data isn’t available yet and we might decide to postpone execution. This could be implemented with a condition: If endDate is not last month’s first day, then terminate or wait/retry. In many cases, if we schedule on the 20th, this step may simply serve to log the range or not be strictly needed. It’s a safeguard for timing issues.
Step 2: Query Subscription Emissions (ItemDetailsReport): Next, an HTTP POST action calls queryCarbonEmissionReports with a JSON body requesting an ItemDetailsReport for subscriptions. We construct the body as described in API Details:
reportType: "ItemDetailReport" (note: the API expects the string "ItemDetailReport" without an "s"
dannyvanderkraan.wordpress.com
).
subscriptionList: the list of subscriptions we want to include. This can be fed from a Logic App parameter or variable. If multiple IDs are provided, the response will include data for each (the portal CSV is typically across one enrollment or one selection of subs; our solution can handle one or many subs).
carbonScopeList: ["Scope1","Scope2","Scope3"] – all scopes.
dateRange: start = last month’s first day, end = last month’s first day (e.g., both "2025-05-01" to get May 2025 data if we are running in June 2025 for latest available May).
categoryType: "Subscription".
orderBy: we can choose "LatestMonthEmissions" (or "totalCarbonEmission") and sortDirection: "Desc" to sort subs by emission size
dannyvanderkraan.wordpress.com
. This matches portal behavior of listing highest emitters first.
(We leave groupCategory empty, and pageSize can be set high like 1000 to ensure no pagination for most cases. If there are more than 1000 subscriptions, the API would return a skipToken, and we’d need a loop to fetch subsequent pages. This would involve a Until loop in the Logic App: call API, append results, then call again with the skipToken until none remains. Most organizations will have far fewer subscriptions to report on, but we note this for completeness.)
The HTTP action will receive a JSON response. We then use a Data Operations – Create CSV table action:
From: We provide the array of subscription data (likely body('HTTP_Subscription_Report').value if we name the HTTP action and use its parsed JSON). We might first use Parse JSON with a schema corresponding to the response to more easily pick fields.
Columns: We specify the mapping for columns. Using the dynamic content or an expression, map itemName -> Subscription_Name, subscriptionId -> Subscription_Id, totalCarbonEmission -> Latest_Month_Emissions_kgCO2E, and totalCarbonEmissionLastMonth -> Previous_Month_Emissions_kgCO2E. The Create CSV action will then output a CSV-formatted text. (If the action is used without custom columns, it will include all fields. Since we want to match the exact portal format, we define the headers explicitly and only the needed fields.)
The output might look like:
"Subscription_Name","Subscription_Id","Latest_Month_Emissions_kgCO2E","Previous_Month_Emissions_kgCO2E"\n"Management","6690c42b-73e0-437c-92f6...","0.981892316510078","0.945248053765905"\n...
file-p9byqvrn4xq64jfg8njquh
 for example.
After constructing the CSV content (which is a string), we add an Azure Blob Storage – Create Blob action:
Storage Account: (already connected via managed identity)
Folder/Container: e.g. carbon-data (whatever container name is configured)
Blob name: e.g. EmissionDetails-Subscription-<MonthYear>.csv. This can be something like EmissionDetails-Subscription-@{formatDateTime(addToTime(utcNow(), -1, 'Month'), 'MMMyyyy')}.csv to take last month in “MMMYYYY” format. If using the date from the API, that might be even more robust (e.g., parse endDate which might be "2025-05-01" and format it as "May2025").
Blob content: The output of the Create CSV table action (which is the CSV text). We should also ensure the blob encoding; by default it will be UTF-8. If needed, we can prepend a BOM or other encoding – not usually necessary unless Excel specific quirks are a concern, but the portal CSV likely is UTF-8 with BOM. A simple approach if BOM is needed is to prepend the content with \uFEFF. This can be done via an expression or a parameter in the create blob action.
Step 3: Query Monthly Emissions Trend (MonthlySummaryReport): Another HTTP POST action calls queryCarbonEmissionReports with reportType: "MonthlySummaryReport". The body parameters:
subscriptionList: same list (the API will return aggregated emissions across those subscriptions for each month, effectively the total emissions of all included subs unless it perhaps splits by sub – but MonthlySummaryReport typically gives a single consolidated trend. If we want per subscription trends, that would require separate calls per subscription or using ItemDetails for each month, which is not what the portal CSV shows. The portal’s EmissionTrends appears to show overall emissions trend across the selected scope of subs). So if the desire is to mimic the portal, and portal likely shows total emissions of all subscriptions selected, then we pass all subs in one call and get one combined time series. If instead one needed trends per subscription, it would be a different output (not asked here).
carbonScopeList: ["Scope1","Scope2","Scope3"].
dateRange: start = (first day of the earliest month to include), end = (first day of the latest month to include). To get the last 12 months, if latest data is for May 2025, we set start = 2024-06-01, end = 2025-05-01 (this yields June 2024 through May 2025 inclusive – 12 data points). Alternatively, use the startDate from the date range API if it’s within last 12 months, otherwise just calculate last 12 months from endDate. (The Carbon Optimization API only retains 12 months
learn.microsoft.com
, so we don’t request more than that. If you attempt a longer range, it may error or just return 12 months.)
We don’t need a categoryType for MonthlySummaryReport – it inherently returns the time series (the API likely ignores categoryType for this report type). The CLI usage suggests just --monthly-summary without a category needed
learn.microsoft.com
.
The response will have an array of monthly data. Each entry includes fields: date, latestMonthEmissions, previousMonthEmissions, carbonIntensity, etc. We will convert this to CSV. However, to match the format with separate Scope1, Scope2, Scope3 columns
file-76pvotbmw8nmdyi2udax8f
, we have two approaches:
Single API call (combined scopes): If we query all scopes at once, the API gives total emissions (which effectively equals Scope3 for Azure usage). We can populate TotalEmissions column from latestMonthEmissions. Since Scope1 and Scope2 are zero in this context (Azure’s operational emissions are reported under Scope3 for the customer), we can fill Scope1 and Scope2 columns with 0 or leave them if data not present. Scope3 would essentially equal TotalEmissions in this scenario. We can set Scope3 column equal to TotalEmissions as well (or if we had separate data we would do differently, but portal CSV likely duplicated that number under scope3 if scopes 1 and 2 are zero). CarbonIntensity comes directly from the API field.
Multiple API calls per scope: Alternatively, we could call the MonthlySummaryReport 3 times, once for each scope, to get separate values, then join them by month. This complicates the logic and is usually unnecessary unless the user specifically wants to see if any Scope1 or Scope2 values exist (in Azure they might not, except possibly for services like Azure Kubernetes Service with something?). Given the portal example CSV shows 0 for Scope1 and Scope2 throughout
file-76pvotbmw8nmdyi2udax8f
, it’s safe to assume method (1) is fine.
We proceed with transforming the JSON to CSV. We might do a slight transformation: create an array of objects where each object has properties Month, TotalEmissions, Scope1, Scope2, Scope3, CarbonIntensity. This can be done with a Select action on the JSON array, mapping:
Month = formatDateTime(item().date, 'MMM yyyy') or similar (or just use the "Month Year" string as given – the API’s date comes as "YYYY-MM-01", we can convert to "MMM YYYY" for readability since the portal export uses that format
file-76pvotbmw8nmdyi2udax8f
).
TotalEmissions = item().latestMonthEmissions
Scope1 = 0 (literal or if by chance item has a breakdown, but it doesn’t; we fill 0)
Scope2 = 0
Scope3 = item().latestMonthEmissions (assuming all in scope3)
CarbonIntensity = item().carbonIntensity
Then feed this array into Create CSV table to get the trend CSV text. The headers will be exactly as above. The resulting CSV will list each month’s data. For example, lines might start like:
"Month","TotalEmissions","Scope1","Scope2","Scope3","CarbonIntensity"
"May 2024","0.1","0","0","0.1","13.1"
"Jun 2024","0.1","0","0","0.1","12.8"
file-76pvotbmw8nmdyi2udax8f
, and so on up to the latest month.
Finally, use another Create Blob action to upload this CSV to Blob Storage. Blob name can be EmissionTrends-<MonthYear>.csv (with MonthYear = latest month in the data, e.g., Apr2025 as in example). The content is the CSV text from the previous step.
Step 4: (Optional) Notifications/Outputs: If desired, add steps to send an email or Teams message confirming the files were updated. Or log an entry to an Application Insights or Log Analytics workspace for monitoring. This could include the blob URL, the date range of data, and any summary (like total emissions last month). While not required, it can be useful for visibility.
Error Handling: We wrap the HTTP calls in a Scope or use the RunAfter property to catch failures. For example, if the carbon API returns an error (non-200 status), the Logic App can detect this and handle it:
If a transient error occurred (network glitch, temporary Azure issue), the HTTP actions can be configured with a Retry Policy. By default, Logic Apps use a default retry for certain status codes. We can explicitly set retryPolicy on the HTTP action (e.g. up to 3 retries with exponential backoff).
If the error is non-transient (e.g., 401 Unauthorized due to missing RBAC, or 400 Bad Request due to a wrong parameter), the Logic App can capture the error message. We could add a step to email the error details to admins, or log it.
Using a Scope action for the group of steps and then an error branch, we can handle any failure in one place (for example, if any of the API calls or blob writes fail, send an alert and stop). This avoids silent failures.
Concurrency and Order: The two main data retrieval branches (subscription detail and monthly trend) can run in parallel since they are independent. In a Logic App designer, we could place them in parallel branches under the recurrence trigger. However, running them sequentially is also fine (the execution time is short for each API call). For simplicity, sequential steps as described is okay. If parallel, ensure both branches each have their own blob writing and error handling, then perhaps converge after.
Testing the Workflow: Before deploying to production, it’s wise to test the Logic App with a smaller dataset. For example, set the subscription list to a single known subscription and run the Logic App (maybe manually trigger it) to see the outputs in blob. Verify the CSV format matches expectations. Also test the scenario where data is not yet available (simulate by setting dateRange to the current month which should fail or return empty) to ensure the Logic App handles it gracefully (perhaps by design it won’t run until the scheduled date anyway).
In summary, the Logic App orchestrates a monthly data fetch and export pipeline: trigger -> call REST API -> transform -> store in Blob, using Azure AD integrated security throughout.
Deployment Plan
To ensure this solution can be set up consistently across environments, we will provide an Infrastructure-as-Code deployment (using Bicep or ARM template, with Azure CLI or PowerShell). The deployment will create all necessary Azure resources and wiring. Key components and steps in the deployment:
Parameters: Define parameters for user-specific settings:
storageAccountName: Name of the Azure Storage account to use (if it must create one, needs to be globally unique). Alternatively, allow passing an existing storage account resource ID.
containerName: Name of the Blob container for output (e.g., "carbon-emissions"). The template can create this container if needed (using Microsoft.Storage/storageAccounts/blobServices/containers resource type).
subscriptionIds: An array of subscription IDs (strings) to export data for. This can default to the deployment subscription or be a list. If the intention is to cover the subscription where the Logic App is deployed, this might be passed automatically. We can also allow a special value like "ALL" or simply instruct that multiple IDs can be given.
scheduleDay and scheduleTime: (Optional) parameters to set the recurrence schedule, e.g., day of month (default 19 or 20) and time (UTC).
logicAppName: Name for the Logic App.
Perhaps carbonApiVersion: default "2025-04-01" (to pin the API version, in case of future changes).
Resource: Storage Account (if needed): If an existing account is not provided, the template can deploy a new Storage Account (Standard GPv2, with soft delete enabled maybe, depending on org’s policy). This would include the specified container. The deployment assigns proper access policies:
We might not assign RBAC to the Logic App here for storage because in ARM template, cross-resource role assignment to storage can be done (by using the Logic App’s principalId once available). We can do that as a separate resource of type Microsoft.Authorization/roleAssignments with scope at the storage account. (Alternatively, handle it manually, but we aim for single-click.)
Resource: Logic App Workflow: Deploy the Logic App (if using Consumption type or Standard type).
For a Consumption logic app, the ARM resource type is Microsoft.Logic/workflows with a child Microsoft.Logic/workflows/versions for definition (or you can embed the definition in the main resource). The template will include the Logic App definition in JSON, which includes the trigger and actions described above. We will incorporate the parameters (like subscription IDs, storage names) into that definition via template expressions. For example, the subscription list in the HTTP body could be an expression that inserts the parameter array. The blob connector action could refer to the storage account and container parameters.
Enable System-Assigned Managed Identity for the Logic App. In ARM, this is done by adding "identity": {"type": "SystemAssigned"} to the workflow resource. This will create an identity with its principalId available after deployment.
If using Standard logic app, the deployment might be slightly different (since Standard has an App Service plan and uses workflow definitions as files). For simplicity, a Consumption logic app is easier to include fully in one template. (Standard could be done with a separate deployment of a Logic App Standard and its workflows, possibly via ARM/Bicep modules. Here we will assume Consumption for the one-click ease.)
Important: The Logic App definition will use the built-in HTTP action with managed identity. In the definition JSON, the HTTP action would have an authentication object like:
"authentication": {
    "type": "ManagedServiceIdentity",
    "identity": "[resourceId('Microsoft.ManagedIdentity/Identities/...')]" // if needed, but for system-assigned, identity property can be simply "tenantId" and "audience"
}
Actually, for system-assigned, one typically provides "authentication": { "type": "ManagedServiceIdentity", "tenantId": "<tenant GUID>", "audience": "https://management.azure.com/" }. The tenantId can be derived from the deployment parameters (or outputs) as well. Azure provides an expression function tenant() to get tenant ID, which can be used in the template for the Logic App definition.
Similarly, for the Azure Blob connector, if using an API connection (Consumption), we would deploy an API connection resource of type Microsoft.Web/connections with properties indicating it uses managed identity auth. However, since mid-2023, consumption connectors support managed identity by configuration. In ARM, this might be complex to set up, so an alternative is to use HTTP with the storage REST API directly, as mentioned. But since we prefer connector approach, we might need to deploy a connection. An easier path: We could use an Azure Storage SDK or Azure Function for writing to blob as part of the logic, but that complicates things. Plan for connections: We can include a resource for the AzureBlob connection:
{
  "type": "Microsoft.Web/connections",
  "name": "azureblob",
  "properties": {
     "displayName": "azureblob",
     "api": { "id": "[subscriptionResourceId('Microsoft.Web/locations/managedApis', '<region>', 'azureblob')]" },
     "parameterValues": {
        "server": "<storageAccountName>.blob.core.windows.net",
        "authType": "ManagedServiceIdentity"
     },
     "parameterValueSet": {
        "name": "secureManaged",
        "values": {
           "resourceId": "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]"
        }
     }
  }
}
This (if supported) would create a connection named "azureblob" using managed identity to the specified storage account. The Logic App workflow definition then can reference this connection for the blob actions. (This is one area that may require fine-tuning, but it’s doable in ARM/Bicep.)
Resource: Role Assignments: After deploying the Logic App and obtaining its identity, the template can assign RBAC roles:
Carbon Optimization Reader role assignment: This is a subscription-level role. In an ARM template, a role assignment can be created with:
{
  "type": "Microsoft.Authorization/roleAssignments",
  "apiVersion": "2022-04-01",
  "name": "[guid(parameters('subscriptionIds')[0], resourceGroup().id, 'carbonRole')]",
  "scope": "[subscriptionResourceId('','')]", // subscription scope (or could loop for each subscription in list)
  "properties": {
     "roleDefinitionId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fa0d39e6-28e5-40cf-8521-1eb320653a4c')]", 
     "principalId": "[reference(resourceId('Microsoft.Logic/workflows', parameters('logicAppName')), '2020-05-01').identity.principalId]"
  }
}
The above is conceptual: we’d likely loop or have one resource per subscription in the list, using the known roleDefinitionId for Carbon Optimization Reader (fa0d39e6-28e5-40cf-8521-1eb320653a4c as per Azure AD role catalog
azadvertizer.net
). This grants the Logic App identity permission to call the carbon APIs on that subscription.
Storage Blob Data Contributor role assignment: Similar approach, but scope would be the storage account:
{
  "type": "Microsoft.Authorization/roleAssignments",
  "name": "[guid(parameters('storageAccountName'), resourceGroup().id, 'blobRole')]",
  "scope": "[resourceId('Microsoft.Storage/storageAccounts', parameters('storageAccountName'))]",
  "properties": {
     "roleDefinitionId": "[subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')]", 
     "principalId": "[reference(resourceId('Microsoft.Logic/workflows', parameters('logicAppName')), '2020-05-01').identity.principalId]"
  }
}
Here ba92f5b4-2d11-453d-a403-e96b0029c9fe is the well-known ID for the Storage Blob Data Contributor role. This ensures the Logic App can write to blobs.
These role assignments can also be done manually if preferred, but including them in the template automates the entire setup.
Deploy via Azure CLI or Portal: The user can deploy the Bicep/ARM template using Azure CLI:
az deployment sub create -f logicapp-carbon-export.bicep -l <region> -p storageAccountName=<name> containerName=<name> subscriptionIds='["<sub1>","<sub2>"]' logicAppName=<name>
This will create all the resources. We should document any necessary Azure CLI extension (for example, deploying logic apps might require the azure-cli-logic extension for ARM template that includes workflows – in newer CLI versions it’s not needed, but to be safe we note it).
Post-Deployment Configuration: After deployment, the Logic App is ready. The user should navigate to the Logic App in the portal to verify:
The managed identity is enabled.
The workflow definition is present and shows the correct steps.
Connections (if any) are authenticated (for example, if using a connection resource for Azure Blob, it should indicate “Connected” using Managed Identity).
The recurrence trigger is enabled (it should be by default). The user can run a trigger manually for an immediate test.
All of these can be encapsulated in an ARM/Bicep template for a “single-click” deployment. Parameters like storage account name, container, schedule, and subscription IDs provide flexibility. The API version (2025-04-01 as of writing) is included to future-proof the REST calls. If needed, the deployment can also output the Logic App’s name or principalId for record. Security & Compliance: By using managed identities and RBAC, the solution adheres to security best practices (no secrets in code). All actions are within the Azure boundary (the Logic App talks to Azure APIs and Azure Storage directly). If a stricter environment requires using Key Vault for any reason (not really needed here since no secret, but perhaps for storing subscription IDs or other config), that could be integrated as well (the Logic App identity could read from Key Vault if we stored config there, given appropriate Vault access). Cleanup and Dev/Test: If deploying for testing, removal is straightforward: delete the resource group or the deployed resources. The role assignments will be removed automatically when the principal (Logic App) is deleted since it’s system-assigned (the identity is destroyed with the Logic App).
Error Handling and Logging
Robust error handling ensures the solution runs reliably month over month and that any issues are detectable:
Logic App Native Error Handling: We utilize Configure run after settings. Each critical action (HTTP calls, file upload) can be followed by a check:
For example, the Blob upload actions can have a runAfter on failure of the previous step to catch errors.
We can group all actions in a Scope and then have a parallel action (or subsequent action) with runAfter: { "<scope>": ["Failed"] } to handle any failure in the scope. In that error handler, we might log the error or send a notification. For instance, an email to admins: “Carbon Export Logic App failed on {Date} with error: <details>”.
The error details (like HTTP status code or message) are available via workflow expressions (e.g., actions('CallCarbonAPI').outputs.statusCode or the body with error message). This can be included in notifications.
Retry Policies: The HTTP actions can be set with custom retry policies (in the code view of the logic app). By default, Azure Logic Apps will automatically retry certain transient failures (HTTP 429, 5xx) up to 4 times with exponential backoff. We can adjust this if needed:
For the carbon API (which is not high-traffic in this scenario), the default might suffice. If we expect occasional timeouts, we could set a fixed retry or increase the count.
Example setting (in JSON definition):
"retryPolicy": {
    "type": "exponential",
    "interval": "PT1M",
    "count": 3
}
to retry up to 3 times with 1 minute initial delay. This is probably fine for most cases. If after retries it still fails, the error handler kicks in.
Data Validation: The Logic App can include some basic checks on the data. For instance, after getting the emissions JSON, if the value array is empty (which could indicate no data or wrong filter), that could be logged as a warning. However, given known usage, if the service returns empty it might mean the service is disabled or scopes misconfigured. We assume correct configuration yields data.
Logging and Diagnostics: We enable Diagnostic Settings for the Logic App. The Logic App’s runs and actions can be logged to Azure Monitor logs. This is configured in the Azure Portal (or via template) by connecting the Logic App to a Log Analytics workspace. All runs (success or failure) and their duration, outputs, etc., can then be queried. This is extremely useful for history and troubleshooting, as it keeps records beyond the 90-day run history retention of Logic Apps.
Alternatively or additionally, we could log a summary of each run to Application Insights (using the Azure Monitor HTTP Data Collector or an Azure Function to send custom events). For simplicity, enabling the built-in diagnostic to Log Analytics is sufficient. It would allow writing Kusto queries like: AzureDiagnostics | where Resource == "<LogicAppName>" and Status_s == "Failed" to find failures.
Azure Monitor Alerts: With logs in place, one can set up an Alert Rule to email or page on failures. For example, an alert if the Logic App run fails or if it hasn’t succeeded in over X days. Another approach: the Logic App itself sends an email on failure as mentioned, which might be simpler for a small setup.
Blob Logging: We might also keep an activity log by writing a small record to a Blob or Table each time the export runs (e.g., a blob lastSuccessfulRun.txt containing a timestamp). However, this duplicates what Log Analytics offers, so it’s optional. Still, writing a simple log entry to a separate blob could make it easy to see in the storage account when the last run was and what data was exported (could include last month and number of subscriptions covered). This could be an additional step in the Logic App, executed after successful data export.
Handling Missing Data: If the Logic App runs but finds that the latest month’s data isn’t available (perhaps it was triggered too early or there was a delay in data publication), the response from the carbon API might be an empty array or a message. The design can handle this by:
Using the date-range check as described to avoid calling for an unavailable month.
If we did call and got no data, the Logic App could either treat it as a failure (to be retried or alerted) or gracefully skip. For instance, a condition: if subscription emissions result array is empty -> send warning email and end. The assumption is that scheduling on the 19th/20th avoids this scenario normally.
Testing Error Paths: We will test scenarios like invalid subscription ID (to see if API returns 400) or missing role (should return 401/403) to ensure our error catching works. During initial deployment, these tests can catch misconfigurations (for example, if we forgot to assign the Carbon Reader role, the HTTP call would 403 Forbidden; our Logic App should log that error clearly so we know to fix the permission).
Idempotence: Each run is independent – it always fetches the latest available data. So if one run fails, the next month’s run can still succeed and produce the latest files. We might want to catch up missing data if a run was missed (e.g., if the Logic App was disabled in July and re-enabled in August, we missed June data). Since the API retains 12 months, a subsequent run could retrieve the backfill (by adjusting date range). This could even be automated: the Logic App could check if the last file on blob is older than one month and decide to generate for the gap. However, this adds complexity. Usually, one run missing isn’t critical if we can manually trigger a one-off run. So we keep the logic simple and manual intervention can be done to backfill if needed (just run the Logic App for the missed period or adjust the date range parameter temporarily).
In essence, the solution logs all activities and handles faults so that issues can be noticed and resolved quickly, ensuring continuous operation.
Optional Configuration and Enhancements
The base solution exports all subscriptions’ data that the managed identity has access to. In some cases, you may want to restrict or select specific subscriptions (for example, only production subscriptions, or grouping by business unit). Here are ways to configure this:
Select Subscriptions: The Logic App’s subscriptionList parameter in the API call can be made dynamic. We can store the list of target subscription IDs in an Azure Logic App parameter or variable. The deployment can allow setting this list (as mentioned in Deployment Plan). To change which subscriptions are included, one can update this parameter (e.g., via Azure Portal’s Logic App Workflow parameters UI or by redeploying with a new list). This avoids hard-coding IDs in the workflow definition. If the user wants to export “all” subscriptions by default, they can provide all relevant IDs. Alternatively, if the Logic App’s identity is granted Reader on an entire tenant (not typical) or multiple subscriptions, one might consider programmatically discovering subscriptions:
For example, a preliminary step could use the Azure Resource Graph or CLI to list subscriptions where tenant = X. However, this would require the identity to have Directory or Tenant list permissions, which complicates the setup. So, the straightforward approach is to maintain the list manually.
The template could accept a flag or special value (like a wildcard) to indicate “all accessible subscriptions”, but implementing that at runtime is non-trivial. It’s safest to explicitly list them.
Selecting Specific Data Scopes: In addition to subscriptions, the API allows filtering by resource group, resource type, or location if needed
learn.microsoft.com
. This solution currently doesn’t use those (it exports entire subscription aggregates). If desired, one could extend the Logic App to run multiple queries for different segments. For instance, you might have separate CSVs per region or per resource type. This could be achieved by altering the categoryType and using groupCategory or filtering lists. For example, set categoryType: ResourceType and maybe group by a certain category to get emissions by service type (VMs vs Storage, etc.). That would produce data similar to the “Emission Details” but grouped differently. This is an extension beyond the core ask, but knowing it’s possible is useful.
Parameterizing Time Range: By default, we always get the last full month (for detail) and last 12 months (for trend). If one wanted the ability to pull a different range (say a yearly summary or a custom range), the Logic App could accept parameters or trigger inputs for start/end dates. For example, a manual trigger with parameters could initiate an on-demand export for a specified period. This would use the same APIs but with provided dates. Our monthly trigger uses fixed logic, but we could add an HTTP Request trigger (to allow manual invocation with parameters) without much extra effort. That way, an admin could call an endpoint (secured by a token or IP restrictions) to generate a CSV for, say, Jan–Dec 2024 if needed.
Deployment Flexibility: We can make the deployment more flexible by using Azure Bicep modules. For instance, one module for Logic App, one for Storage, one for role assignments. This would allow easily enabling/disabling parts (if user already has a storage account, they skip that module, etc.). Our single template approach covers common cases but can be adjusted.
Documentation and Links: We include links to official documentation for reference:
Microsoft’s What is Carbon Optimization docs (emissions data background and RBAC)
learn.microsoft.com
learn.microsoft.com
.
The REST API reference for Carbon Emission Reports (for developers to consult for advanced queries) – Microsoft Learn: Carbon Service – Query Carbon Emission Reports
learn.microsoft.com
.
Azure Logic Apps documentation on using Managed Identity for HTTP and connectors
learn.microsoft.com
learn.microsoft.com
.
Azure Blob Storage RBAC docs (to understand roles like Storage Blob Data Contributor).
These resources help users understand and extend the solution as needed.
Limitations: Current limitations of the solution/design:
Data freshness: As noted, data is only updated monthly (no intra-month updates) and available mid-month for the prior month
learn.microsoft.com
. This solution cannot speed that up; it relies on the Azure service’s schedule.
Historical data beyond 12 months: The Carbon Optimization API only provides 12 months rolling window
learn.microsoft.com
. If longer history is required, you must rely on the stored CSV archives or use other tools like the Emissions Impact Dashboard (which can provide up to 5 years of data
learn.microsoft.com
). Our Logic App could be run manually prior to the 12-month cutoff to backfill data and preserve it in storage if needed.
Granularity: The CSV exports are at subscription and monthly granularity. If per-resource or daily granularity is needed, it would require adjustments (the API currently doesn’t give daily data, only monthly). Per-resource data for the last month is possible (by setting categoryType = Resource), and one could export a very detailed CSV. But that might be a large file if a subscription has thousands of resources. A possible future improvement is to make the report type configurable (e.g., a parameter to choose Subscription vs Resource detail).
Costs: The Carbon Optimization features are free (no cost) for all Azure customers
learn.microsoft.com
, and Logic Apps and storage have minimal costs. The Logic App will run once a month and do two API calls and two blob writes – this is extremely low usage (pennies per month in Azure Logic Apps consumption costs). Storage cost for CSVs is negligible (a year’s worth of monthly CSVs, each perhaps a few KB to MB). So cost is not a big concern, but worth mentioning that Logic App consumption pricing is per action and trigger – with maybe ~10 actions per run, that’s on the order of <0.01 USD per run. If using Standard (with fixed pricing), it’s also minimal given low frequency.
After deploying and configuring, the solution will provide deployment-ready, automated exports of carbon emissions data. It aligns with Microsoft’s best practices for sustainability data access (using the official APIs and RBAC roles) and cloud automation (serverless Logic App with no custom servers). The user can now integrate these CSV outputs with internal dashboards or processes (for example, ingesting into Power BI or a database) knowing that each month’s data will be captured automatically. References:
Microsoft Learn – Azure Carbon Optimization: Data availability and retention
learn.microsoft.com
Microsoft Learn – Azure Carbon Optimization: Permissions (Carbon Optimization Reader role)
learn.microsoft.com
Microsoft Learn – Azure Carbon Optimization REST API (CLI usage examples)
learn.microsoft.com
learn.microsoft.com
GitHub (OpenCost) – Example of calling Carbon Optimization API with JSON body
github.com
Xebia Blog – Using the Carbon Optimization API (HTTP POST and Bearer auth)
articles.xebia.com
articles.xebia.com
Azure Q&A – Using Logic App Managed Identity for Blob Storage (assigning Blob Contributor role)
learn.microsoft.com
learn.microsoft.com
User-provided sample CSV formats: Emission Details
file-p9byqvrn4xq64jfg8njquh
 and Emission Trends
file-76pvotbmw8nmdyi2udax8f
 (for verifying output schema).
Citations
Favicon
What is Carbon optimization in Azure - Carbon optimization in Azure | Microsoft Learn

https://learn.microsoft.com/en-us/azure/carbon-optimization/overview
Favicon
Measuring Sustainable Software Engineering: Environmental Perspective

https://articles.xebia.com/microsoft-services/sustainable-software-engineering-through-the-lens-of-environmental-measuring
EmissionDetails-Subscription-Apr2025.csv

file://file-P9bYqvrN4Xq64Jfg8NjQuH
EmissionTrends-Apr2025.csv

file://file-76PvoTBMW8NMDyi2udAx8f
Favicon
Integrate Azure carbon emission data into carbon cost reporting · Issue #2773 · opencost/opencost · GitHub

https://github.com/opencost/opencost/issues/2773
Favicon
Measuring Sustainable Software Engineering: Environmental Perspective

https://articles.xebia.com/microsoft-services/sustainable-software-engineering-through-the-lens-of-environmental-measuring
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Measure Your Carbon Footprint on Azure Programmatically With the Carbon Optimization REST APIs | Danny van der Kraan's Blog

https://dannyvanderkraan.wordpress.com/2024/03/04/measure-your-carbon-footprint-on-azure-programmatically-with-the-carbon-optimization-rest-apis/
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Integrate Azure carbon emission data into carbon cost reporting · Issue #2773 · opencost/opencost · GitHub

https://github.com/opencost/opencost/issues/2773
Favicon
Measure Your Carbon Footprint on Azure Programmatically With the Carbon Optimization REST APIs | Danny van der Kraan's Blog

https://dannyvanderkraan.wordpress.com/2024/03/04/measure-your-carbon-footprint-on-azure-programmatically-with-the-carbon-optimization-rest-apis/
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
Favicon
Integrate Azure carbon emission data into carbon cost reporting · Issue #2773 · opencost/opencost · GitHub

https://github.com/opencost/opencost/issues/2773
Favicon
Integrate Azure carbon emission data into carbon cost reporting · Issue #2773 · opencost/opencost · GitHub

https://github.com/opencost/opencost/issues/2773
Favicon
Integrate Azure carbon emission data into carbon cost reporting · Issue #2773 · opencost/opencost · GitHub

https://github.com/opencost/opencost/issues/2773
Favicon
Integrate Azure carbon emission data into carbon cost reporting · Issue #2773 · opencost/opencost · GitHub

https://github.com/opencost/opencost/issues/2773
Favicon
Carbon Service - Query Carbon Emission Reports - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-reports?view=rest-carbon-2025-04-01
EmissionTrends-Apr2025.csv

file://file-76PvoTBMW8NMDyi2udAx8f
Favicon
Carbon Service - Query Carbon Emission Data Available Date Range - REST API (Azure Carbon optimization) | Microsoft Learn

https://learn.microsoft.com/en-us/rest/api/carbon/carbon-service/query-carbon-emission-data-available-date-range?view=rest-carbon-2025-04-01
Favicon
Measuring Sustainable Software Engineering: Environmental Perspective

https://articles.xebia.com/microsoft-services/sustainable-software-engineering-through-the-lens-of-environmental-measuring
Favicon
az carbon | Microsoft Learn

https://learn.microsoft.com/en-us/cli/azure/carbon?view=azure-cli-latest
Favicon
Assign access to Carbon optimization in Azure - Carbon optimization in Azure | Microsoft Learn

https://learn.microsoft.com/en-us/azure/carbon-optimization/permissions
Carbon Optimization Reader - fa0d39e6-28e5-40cf-8521-1eb320653a4c

https://www.azadvertizer.net/azrolesadvertizer/fa0d39e6-28e5-40cf-8521-1eb320653a4c.html
Favicon
Assign access to Carbon optimization in Azure - Carbon optimization in Azure | Microsoft Learn

https://learn.microsoft.com/en-us/azure/carbon-optimization/permissions
Favicon
How to access the Carbon Optimization Service as an admin? - Microsoft Q&A

https://learn.microsoft.com/en-us/answers/questions/1826079/how-to-access-the-carbon-optimization-service-as-a
Favicon
Connecting Storage Account to Logic App with Managed Identity - Microsoft Q&A

https://learn.microsoft.com/en-us/answers/questions/1437886/connecting-storage-account-to-logic-app-with-manag
Favicon
Assign access to Carbon optimization in Azure - Carbon optimization in Azure | Microsoft Learn

https://learn.microsoft.com/en-us/azure/carbon-optimization/permissions
Favicon
Connecting Storage Account to Logic App with Managed Identity - Microsoft Q&A

https://learn.microsoft.com/en-us/answers/questions/1437886/connecting-storage-account-to-logic-app-with-manag
Favicon
Connecting Storage Account to Logic App with Managed Identity - Microsoft Q&A

https://learn.microsoft.com/en-us/answers/questions/1437886/connecting-storage-account-to-logic-app-with-manag
Favicon
Measure Your Carbon Footprint on Azure Programmatically With the Carbon Optimization REST APIs | Danny van der Kraan's Blog

https://dannyvanderkraan.wordpress.com/2024/03/04/measure-your-carbon-footprint-on-azure-programmatically-with-the-carbon-optimization-rest-apis/
Favicon
Measure Your Carbon Footprint on Azure Programmatically With the Carbon Optimization REST APIs | Danny van der Kraan's Blog

https://dannyvanderkraan.wordpress.com/2024/03/04/measure-your-carbon-footprint-on-azure-programmatically-with-the-carbon-optimization-rest-apis/
Favicon
What is Carbon optimization in Azure - Carbon optimization in Azure | Microsoft Learn

https://learn.microsoft.com/en-us/azure/carbon-optimization/overview
Favicon
What is Carbon optimization in Azure - Carbon optimization in Azure | Microsoft Learn

https://learn.microsoft.com/en-us/azure/carbon-optimization/overview
Favicon
az carbon | Microsoft Learn

https://learn.microsoft.com/en-us/cli/azure/carbon?view=azure-cli-latest
Favicon
Measuring Sustainable Software Engineering: Environmental Perspective

https://articles.xebia.com/microsoft-services/sustainable-software-engineering-through-the-lens-of-environmental-measuring
All Sources