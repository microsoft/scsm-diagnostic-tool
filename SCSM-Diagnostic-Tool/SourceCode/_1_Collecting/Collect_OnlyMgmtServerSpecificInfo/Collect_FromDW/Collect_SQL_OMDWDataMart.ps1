﻿function Collect_SQL_OMDWDataMart() {
    if ($SQLInstance_SCSMDW_OMDM -ne $null  -and  $SQLDatabase_SCSMDW_OMDM -ne $null) {
        $SQL_SCSM_DWOMDM =@{}
        $SQL_SCSM_DWOMDM['SQL_TableSizeInfo_OMDWDataMart']=$SQL_SCSM_Shared['SQL_TableSizeInfo']
        $SQL_SCSM_DWOMDM['SQL_DWFactConstraintsIssue_OMDWDatamart']=$SQL_DWFactConstraintsIssue
#        $SQL_SCSM_DWOMDM['SQL_DWFactConstraintsIssue_OMDWDatamart_ForDebugging']=$SQL_DWFactConstraintsIssue_ForDebugging
        $SQL_SCSM_DWOMDM['SQL_FKIssuesInDW_OMDWDatamart']=$SQL_DWFKIssues
        $SQL_SCSM_DWOMDM['SQL_DWFactEntityUpgradeIssue_OMDWDataMart']=$SQL_DWFactEntityUpgradeIssue
        $SQL_SCSM_DWOMDM['SQL_DWEtlConfiguration_OMDWDataMart']=$SQL_DWEtlConfiguration
        $SQL_SCSM_DWOMDM['SQL_DWEtlWarehouseEntityGroomingHistory_OMDWDataMart']=$SQL_DWEtlWarehouseEntityGroomingHistory
        $SQL_SCSM_DWOMDM['SQL_DWEtlWarehouseEntityGroomingInfo_OMDWDataMart']=$SQL_DWEtlWarehouseEntityGroomingInfo
        $SQL_SCSM_DWOMDM['SQL_information_schema_columns_OMDWDataMart']=$SQL_SCSM_Shared['SQL_information_schema_columns']
        $SQL_SCSM_DWOMDM['SQL_indexes_OMDWDataMart']=$SQL_SCSM_Shared['SQL_indexes']
        $SQL_SCSM_DWOMDM['SQL_DbUsersInfo_OMDWDataMart']=$SQL_SCSM_Shared['SQL_DbUsersInfo']

        foreach($SQL_SCSM_DWOMDM_Text in $SQL_SCSM_DWOMDM.Keys) {  
        
            RamSB -outputString "$SQL_SCSM_DWOMDM_Text.csv" -pscriptBlock `            {        
                SaveSQLResultSetsToFiles $SQLInstance_SCSMDW_OMDM $SQLDatabase_SCSMDW_OMDM ($SQL_SCSM_DWOMDM[$SQL_SCSM_DWOMDM_Text]) "$SQL_SCSM_DWOMDM_Text.csv"    
            }
        }
    }
}