trigger SPOC_Unit_SOL on KNDY4__Sales_Order_Line__c (after update) {
    Map <Id, KNDY4__Sales_Order_Line__c>oMap = new Map<Id, KNDY4__Sales_Order_Line__c>();
    oMap = Trigger.oldMap;
    KNDY4__Sales_Order_Line__c oldSOL = new KNDY4__Sales_Order_Line__c();
    List<SPOC_Quality_Assurance__c> unitsToInsert = new List<SPOC_Quality_Assurance__c>();
    List<SPOC_Quality_Assurance__c> unitsToUpdate = new List<SPOC_Quality_Assurance__c>();
    List<SPOC_Quality_Assurance__c> unitsToDelete = new List<SPOC_Quality_Assurance__c>();
    List<SPOC_Quality_Assurance__c> existingUnits = [SELECT Id, Sales_Order_Line__c, Work_Order__r.KNDY4__Status__c FROM SPOC_Quality_Assurance__c
                                                   WHERE Sales_Order_Line__c IN :Trigger.New];
    if (existingUnits == null) {
        existingUnits = new List<SPOC_Quality_Assurance__c>();
    }
    Map<String, List<SPOC_Quality_Assurance__c>> unitMap = new Map<String, List<SPOC_Quality_Assurance__c>>(); //map sol id to list of related units
    for(SPOC_Quality_Assurance__c unit : existingUnits){
        List<SPOC_Quality_Assurance__c> solUnits = new List<SPOC_Quality_Assurance__c>();
        if (unitMap.containsKey(unit.Sales_Order_Line__c)) {
            solUnits = unitMap.get(unit.Sales_Order_Line__c); //get list of units which have already been mapped
        }
        solUnits.add(unit);
        unitMap.put(unit.Sales_Order_Line__c, solUnits);
    }
    for(KNDY4__Sales_Order_Line__c newSOL : Trigger.New){
        oldSOL = oMap.get(newSOL.Id);
        if (newSOL.KNDY4__Fulfillment_Source__c != 'Build To Order') { continue; } // don't manage units for sol not built to order
        if(unitMap.isEmpty() || newSOL.KNDY4__Quantity_Ordered__c != unitMap.get(newSOL.Id).size() || !unitMap.containsKey(newSOL.Id)){ 
            if(newSOL.KNDY4__Status__c == 'Open' && (oldSOL.KNDY4__Quantity_Ordered__c != newSOL.KNDY4__Quantity_Ordered__c || oldSOL.KNDY4__Status__c == 'Draft')){
                Integer numUnitsAlreadyCreated = unitMap.containsKey(newSOL.Id) ? unitMap.get(newSOL.Id).size() : 0;
                Integer numUnitsToCreate = Integer.Valueof(newSOL.KNDY4__Quantity_Ordered__c) - numUnitsAlreadyCreated;
                if(numUnitsToCreate > 0 ){
                for(Integer i = 0; i < numUnitsToCreate; i++){
                    SPOC_Quality_Assurance__c newUnit = new SPOC_Quality_Assurance__c();
                    newUnit.Sales_Order_Line__c = newSOL.Id;
                    newUnit.Sales_Order__c = newSOL.KNDY4__Sales_Order__c;
                    newUnit.Work_Order__c = newSOL.KNDY4__Work_Order__c;
                    unitsToInsert.add(newUnit);
                } 
                } else {
                    for(Integer i=numUnitsToCreate; i < 0; i++ ){
                        for( SPOC_Quality_Assurance__c unitToDelete : unitMap.get(newSOL.Id)){
                        if(unitToDelete.Work_Order__r.KNDY4__Status__c != 'Cancelled'){ continue;
                        } else { unitsToDelete.add(unitToDelete); }
                        }   
                }   
                }
            }
        }
            else if(oldSOL.KNDY4__Work_Order__c != newSOL.KNDY4__Work_Order__c && newSOL.KNDY4__Work_Order__c != null) { // update units under this condition
                if(!unitMap.containsKey(newSOL.Id)){ continue; } // skid if wo has no sol ref or if no units mapped
                for (SPOC_Quality_Assurance__c unitToUpdate : unitMap.get(newSOL.Id)){
                    unitToUpdate.Work_Order__c = newSOL.KNDY4__Work_Order__c;
                    unitsToUpdate.add(unitToUpdate);
                }
            }
            else if(newSOL.KNDY4__Status__c == 'Cancelled'){
            if (!unitMap.containsKey(newSOL.Id)) { continue; } // skip if no units mapped
            for (SPOC_Quality_Assurance__c unitToDelete : unitMap.get(newSOL.Id)){
                if(unitToDelete.Work_Order__r.KNDY4__Status__c != 'Cancelled'){ continue;
                } else { unitsToDelete.add(unitToDelete); }
            }
            }
    
    if(!unitsToInsert.isEmpty()){
        upsert unitsToInsert;
    }
    if(!unitsToUpdate.isEmpty()){
        update unitsToUpdate;
    }
    if(!unitsToDelete.isEmpty()){
        delete unitsToDelete;
    }
}

}
