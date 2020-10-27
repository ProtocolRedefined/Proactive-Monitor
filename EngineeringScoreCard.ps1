param(
    [String]$teamName = "Pipelines Application and Web Platform",
    [int]$headCount = 11,
    [String]$areaPath = "AzureDevOps\VSTS\Apps\Pipelines Application and Web Platform"
)

$organization = "https://dev.azure.com/mseng"
$project = "AzureDevOps"


function UrlEncode ([string]$witQuery) {
    # Write-Host "witQuery : $($witQuery)"
    [string]$encodedUrl = [System.Web.HttpUtility]::UrlEncode($witQuery, [System.Text.Encoding]::UTF8)
    # Write-Host "encoded url : $($encodedurl)"
    return $encodedUrl
}

function AppendTrackingDataEngineeringScoreCard([string]$url) {
    #{"Source":"ProAct", "Script":"Boards.ps1", "Section":"EngineeringScoreCard"}
    return $url + "&tracking_data=eyJTb3VyY2UiOiJQcm9BY3QiLCAiU2NyaXB0IjoiQm9hcmRzLnBzMSIsICJTZWN0aW9uIjoiRW5naW5lZXJpbmdTY29yZUNhcmQifQ=="
}

function GetWorkItems ([string]$org, [string]$wiqlQuery) {
    # Write-Host "witQuery : $($wiqlQuery)"
    $workItems = az boards query --org $org --wiql $wiqlQuery -o json | ConvertFrom-Json
    return $workItems.Count, $workItems
}


$wiql_StaleLSIrepairWorkItems = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [IcM.Severity] >= 0 AND [IcM.Severity] <= 2 AND ( [System.Tags] CONTAINS 'LSI work' OR [System.Tags] CONTAINS 'Live Site Repair' OR [System.Tags] CONTAINS 'Incident Repair Item' OR [System.Tags] CONTAINS 'LSI Repair Item' ) AND ( [System.State] <> 'Completed' AND [System.State] <> 'Cut' AND [System.State] <> 'Closed' AND [System.State] <> '6 - Closed' ) AND (( [IcM.DeliveryType] = 'ShortTerm' AND [System.CreatedDate] <= @today - 10 ) OR ( [IcM.DeliveryType] = 'MediumTerm' AND [System.CreatedDate] <= @today - 90 ) OR ( [IcM.DeliveryType] = 'LongTerm' AND [System.CreatedDate] <= @today - 365 )) AND [System.AreaPath] UNDER '{0}'"
$wiql_StaleDTSs = "SELECT [System.Id], [System.WorkItemType], [System.Title], [System.State], [System.AssignedTo], [System.CreatedDate], [Microsoft.VSTS.Common.Priority], [System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'DTS Task' and [System.State] = '5 - PG Engaged' and [Custom.Whogottheball] = 'Product Group' and ((([Microsoft.VSTS.Common.Priority] = 0 or [Microsoft.VSTS.Common.Priority] = 1) and [System.CreatedDate] <= @Today - 3) or ([Microsoft.VSTS.Common.Priority] = 2 and [System.CreatedDate] <= @Today - 7) or ([Microsoft.VSTS.Common.Priority] = 3 and [System.CreatedDate] <= @Today - 14) or ([Microsoft.VSTS.Common.Priority] = 4 and [System.CreatedDate] <= @Today - 21)) AND  ([System.AreaPath] UNDER  '{0}')"
$wiql_ActiveP0Bugs = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active' AND [Microsoft.DevDiv.IssueType] <> 'Localization' AND [Microsoft.DevDiv.IssueType] <> 'tracking' AND [Microsoft.VSTS.Common.Priority] = 0 AND [System.AreaPath] UNDER '{0}'"
$wiql_StaleP1Bugs = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active' AND [Microsoft.DevDiv.IssueType] <> 'Localization' AND [Microsoft.DevDiv.IssueType] <> 'tracking' AND [Microsoft.VSTS.Common.Priority] = 1 AND [System.CreatedDate] <= @today - 21 AND [System.AreaPath] UNDER '{0}'"
$wiql_BugsPerEngineer = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath]  FROM WorkItems WHERE [System.WorkItemType] = 'Bug' and [System.State] = 'Active' and [Microsoft.DevDiv.IssueType] <> 'Localization' and [Microsoft.VSTS.Common.IsA11yBug] <> 'Yes' and [Microsoft.DevDiv.IssueType] <> 'tracking' AND  ([System.AreaPath] UNDER  '{0}')"
$wiql_StaleSecurityWorkItems = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE ( [System.WorkItemType] <> 'Live Site Incident' AND [System.WorkItemType] <> 'Live Site Knowledge Base' AND [System.WorkItemType] <> 'Live Site Problem' AND [System.WorkItemType] <> 'Live Site Change Request' ) AND ( [System.State] = 'Active' OR [System.State] = 'In Progress' OR [System.State] = 'Proposed' OR [System.State] = 'Committed' ) AND ( [Microsoft.DevDiv.TenetAffected] = 'Trustworthy and Secure' OR ( [System.Tags] CONTAINS 'Security' OR [System.Tags] CONTAINS 'VSORedBlue' OR [System.Tags] CONTAINS 'VSTSRedBlue' OR [System.Tags] CONTAINS 'PenTest' OR [System.Tags] CONTAINS 'VSOSIM' OR [System.Tags] CONTAINS 'Threat Model' )) AND [System.Tags] NOT CONTAINS '1CS' AND [Microsoft.DevDiv.IssueType] <> 'tracking' AND [System.CreatedDate] <= @today - 21 AND [System.AreaPath] UNDER '{0}'"
$wiql_StaleAccessibilityBugs = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active' AND ( [Microsoft.VSTS.Common.IsA11yBug] = 'Yes' OR [System.Tags] CONTAINS 'A11yMAS' ) AND [System.Tags] NOT CONTAINS 'A11yPlan' AND [System.CreatedDate] <= @today - 42 AND [System.AreaPath] UNDER '{0}'"
$wiql_StaleReliabilityBugs = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active' AND [System.Tags] CONTAINS 'CI_Reliability' AND [System.CreatedDate] <= @today - 21 AND [System.AreaPath] UNDER '{0}'"

$wiql_approachSLA_StaleLSIrepair = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [IcM.Severity] >= 0 AND [IcM.Severity] <= 2 AND ( [System.Tags] CONTAINS 'LSI work' OR [System.Tags] CONTAINS 'Live Site Repair' OR [System.Tags] CONTAINS 'Incident Repair Item' OR [System.Tags] CONTAINS 'LSI Repair Item' ) AND ( [System.State] <> 'Completed' AND [System.State] <> 'Cut' AND [System.State] <> 'Closed' AND [System.State] <> '6 - Closed' ) AND (( [IcM.DeliveryType] = 'ShortTerm' AND [System.CreatedDate] <= @today - 0 ) OR ( [IcM.DeliveryType] = 'MediumTerm' AND [System.CreatedDate] <= @today - 78 ) OR ( [IcM.DeliveryType] = 'LongTerm' AND [System.CreatedDate] <= @today - 353 )) AND [System.AreaPath] UNDER '{0}'"
$wiql_approachSLA_StaleDTSs = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'DTS Task' AND [System.State] = '5 - PG Engaged' AND [Microsoft.DevDiv.SubStatus] = 'Product Group' AND ((( [Microsoft.VSTS.Common.Priority] = 0 OR [Microsoft.VSTS.Common.Priority] = 1 ) AND [System.CreatedDate] <= @today - 0 ) OR ( [Microsoft.VSTS.Common.Priority] = 2 AND [System.CreatedDate] <= @today - 0 ) OR ( [Microsoft.VSTS.Common.Priority] = 3 AND [System.CreatedDate] <= @today - 2 ) OR ( [Microsoft.VSTS.Common.Priority] = 4 AND [System.CreatedDate] <= @today - 9 )) AND [System.AreaPath] UNDER '{0}'"
$wiql_approachSLA_StaleP1Bugs = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active' AND [Microsoft.DevDiv.IssueType] <> 'Localization' AND [Microsoft.DevDiv.IssueType] <> 'tracking' AND [Microsoft.VSTS.Common.Priority] = 1 AND [System.CreatedDate] <= @today - 9 AND [System.AreaPath] UNDER '{0}'"
$wiql_approachSLA_StaleSecurity = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE ( [System.WorkItemType] <> 'Live Site Incident' AND [System.WorkItemType] <> 'Live Site Knowledge Base' AND [System.WorkItemType] <> 'Live Site Problem' AND [System.WorkItemType] <> 'Live Site Change Request' ) AND ( [System.State] = 'Active' OR [System.State] = 'In Progress' OR [System.State] = 'Proposed' OR [System.State] = 'Committed' ) AND ( [Microsoft.DevDiv.TenetAffected] = 'Trustworthy and Secure' OR ( [System.Tags] CONTAINS 'Security' OR [System.Tags] CONTAINS 'VSORedBlue' OR [System.Tags] CONTAINS 'VSTSRedBlue' OR [System.Tags] CONTAINS 'PenTest' OR [System.Tags] CONTAINS 'VSOSIM' OR [System.Tags] CONTAINS 'Threat Model' )) AND [System.Tags] NOT CONTAINS '1CS' AND [Microsoft.DevDiv.IssueType] <> 'tracking' AND [System.CreatedDate] <= @today - 9 AND [System.AreaPath] UNDER '{0}'"

$wiql_approachSLA_StaleReliability = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.State],[System.AssignedTo],[System.CreatedDate],[Microsoft.VSTS.Common.Priority],[System.AreaPath] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active' AND [System.Tags] CONTAINS 'CI_Reliability' AND [System.CreatedDate] <= @today - 9 AND [System.AreaPath] UNDER '{0}'"
# [ScoreCardQuery]$surface = [ScoreCardQuery]::new($wiql_StaleDTSs, 0)


$wiql_EngineeringScoreCard = [ordered]@{
    'StaleAccessibilityBugs'  = [ScoreCardQuery]::new('Stale accessibility bugs', $wiql_StaleAccessibilityBugs, $null, 0)
    'StaleLsiRepairItems'  = [ScoreCardQuery]::new('Stale LSI repair items', $wiql_StaleLSIrepairWorkItems, $wiql_approachSLA_StaleLSIrepair, 0)
    'StaleDTSs'              = [ScoreCardQuery]::new('Stale DTSs', $wiql_StaleDTSs, $wiql_approachSLA_StaleDTSs, 0) 
    'ActiveP0Bugs'          = [ScoreCardQuery]::new('Active P0 bugs', $wiql_ActiveP0Bugs, $null, 0)
    'StaleP1Bugs'           = [ScoreCardQuery]::new('Stale P1 Bugs', $wiql_StaleP1Bugs, $wiql_approachSLA_StaleP1Bugs, 0)
    'BugsPerEngineer'       = [ScoreCardQuery]::new('Bugs Per Engineer', $wiql_BugsPerEngineer, $null, 5)
    'StaleSecurityItems'    = [ScoreCardQuery]::new('Stale security items', $wiql_StaleSecurityWorkItems, $wiql_approachSLA_StaleSecurity, 5)
    'StaleReliabilityItems' = [ScoreCardQuery]::new('Stale reliability items', $wiql_StaleReliabilityBugs, $wiql_approachSLA_StaleReliability, 0)  
}


# team headcount reference  https://dev.azure.com/mseng/_git/AzureDevOps?path=%2FTools%2FExtensions%2FEngineeringScorecard%2Fscripts%2FImplementation%2FTeamsProvider.ts&version=GBmaster
$teams = [ordered]@{
    #'Search Core' = [TeamDetails]::new("Search core", 15, "AzureDevOps\VSTS\RM and Deployment\RM-Service")
    # 'Search Core' = [TeamDetails]::new("Search core", 15, "AzureDevOps\VSTS\Modern Interactions and Search\Search Core")
    # 'ProTocol' = [TeamDetails]::new("ProToCol", 12, "AzureDevOps\VSTS\Modern Interactions\ProToCol")  
    # 'Boards'                                 = [TeamDetails]::new("Boards", 6, "AzureDevOps\VSTS\Apps\Boards")  
    'team' = [TeamDetails]::new($teamName, $headCount, $areaPath)  
    
}

$areapath_engScoreCard = New-Object 'system.collections.generic.dictionary[[string],[TeamScoreCardOutput]]'

foreach ($teamName in $teams.Keys) {
    $team = $teams[$teamName]
    $areapath = $team.areapath
    Write-Host "team$($teamName)  areaPath $($areapath)     Head Count $($team.headCount)"
   
    [TeamScoreCardOutput]$teamScoreOutput = [TeamScoreCardOutput]::new($team)

    foreach ($scoreCardAttributes in $wiql_EngineeringScoreCard.Keys) { 
        $scoreCardAttr = $wiql_EngineeringScoreCard[$scoreCardAttributes]
        $finalQuery = [string]::Format($scoreCardAttr.wiqlQuery, $areapath)
        $witCount, $wits = GetWorkItems $organization $finalQuery
        Write-Host "output $($scoreCardAttributes)   $($witCount)       $($scoreCardAttr.threshold)"

        $scoreCardQueryUrl = $organization + "/" + $project + "/_queries/query?wiql=" + $(UrlEncode($finalQuery))
        
        if ($scoreCardAttr.wiqlQueryApproachSLA -ne "") {
            $approachSLA_finalQuery = [string]::Format($scoreCardAttr.wiqlQueryApproachSLA, $areapath)
            $approachSLA_witCount, $approachSLA_wits = GetWorkItems $organization $approachSLA_finalQuery
            
            $approachQueryUrl = $organization + "/" + $project + "/_queries/query?wiql=" + $(UrlEncode($approachSLA_finalQuery))
        }
        else {
            $approachSLA_finalQuery = ""
            $approachSLA_witCount = 0
            $approachSLA_wits = $null
            $approachQueryUrl = ""
        }

        if($scoreCardAttributes -eq "BugsPerEngineer") {
            # Write-Output "hi"
            $witCount = $witCount/$headCount
        }

        [ScoreCardQueryOutput]$queryOutput = [ScoreCardQueryOutput]::new($scoreCardAttr.name, $finalQuery, $approachSLA_finalQuery, $scoreCardAttr.threshold, $witCount, $($approachSLA_witCount - $witCount))
        $queryOutput.setScoreCardQueryUrl($scoreCardQueryUrl);
        $queryOutput.setApproachQueryUrl($approachQueryUrl);
        $teamScoreOutput.AddScoreCardQueryOutput($scoreCardAttributes, $queryOutput)
    }
    # remove team name hardcoded value to $teamName. this is added to make sure it works only for one team and key is constant
    $areapath_engScoreCard.Add("teamscorecard", $teamScoreOutput)
}
 

$resultJson = ConvertTo-Json -InputObject $areapath_engScoreCard -Depth 10 -Compress
# $resultJson = $resultJson -replace '\\', '\'
$resultJson

# $singleLineJson = $resultJson -split "(\r*\n){2,}"

# remove linefeeds for each section and output the contents
# $singleLineJson = $singleLineJson -replace '\r*\n', ''
# $singleLineJson = $singleLineJson -replace '\\\\', '\'
# $singleLineJson


class ScoreCardQuery {
    [string]$name
    [string]$wiqlQuery
    [string]$wiqlQueryApproachSLA
    [int]$threshold
    [string]$scoreCardQueryUrl
    [string]$approachQueryUrl
 
    ScoreCardQuery(
        [string]$name,
        [string]$wiqlQuery,
        [string]$wiqlQueryApproachSLA,
        [int]$threshold
    ) {
        $this.name = $name
        $this.wiqlQuery = $wiqlQuery
        $this.wiqlQueryApproachSLA = $wiqlQueryApproachSLA
        $this.threshold = $threshold
    }

    [void] setScoreCardQueryUrl([string]$scoreCardQueryUrl) {
        $this.scoreCardQueryUrl = $scoreCardQueryUrl
    }

    [void] setApproachQueryUrl([string]$approachQueryUrl) {
        $this.approachQueryUrl = $approachQueryUrl
    }
}

class ScoreCardQueryOutput : ScoreCardQuery {
    [int]$count
    [int]$approachSLACount
    [bool]$needsAttention
 
    ScoreCardQueryOutput([string]$name, [string]$wiqlQuery, [string]$wiqlQueryApproachSLA, [int]$threshold, [int]$count, [int]$approachSLACount) : base($name, $wiqlQuery, $wiqlQueryApproachSLA, $threshold) {
        $this.count = $count
        $this.approachSLACount = $approachSLACount
        $this.needsAttention = ($this.count -gt $this.threshold)
    }
}

class TeamDetails {
    [string]$name
    [int]$headCount
    [string]$areaPath
    
    TeamDetails(
        [string]$name,
        [int]$headCount,
        [string]$areapath        
    ) {
        $this.name = $name
        $this.headCount = $headCount
        $this.areapath = $areapath
    }
}

class TeamScoreCardOutput {
    [TeamDetails]$teamDetails
    $scoreCardOutputs = [ordered]@{ }
    #[ScoreCardQueryOutput]$scoreCardQueryOutput
    
    TeamScoreCardOutput(
        [TeamDetails]$teamDetails
    ) {
        $this.teamDetails = $teamDetails
    }

    #GetScoreCardQueryOutput() {
    #   return $this.scoreCardOutputs
    #}

    [void] AddScoreCardQueryOutput([string]$name, [ScoreCardQueryOutput]$queryOutput) {
        ## Add argument validation logic here
        $this.scoreCardOutputs[$name] = $queryOutput
    }
}
