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
    //Set<Id> SOLSet = new Set<Id>();
    //Integer j;
    Map<String, List<SPOC_Quality_Assurance__c>> unitMap = new Map<String, List<SPOC_Quality_Assurance__c>>(); //map sol id to list of related units
    for(SPOC_Quality_Assurance__c unit : existingUnits){
        List<SPOC_Quality_Assurance__c> solUnits = new List<SPOC_Quality_Assurance__c>();
        if (unitMap.containsKey(unit.Sales_Order_Line__c)) {
            solUnits = unitMap.get(unit.Sales_Order_Line__c); //get list of units which have already been mapped
        }
        solUnits.add(unit);
        unitMap.put(unit.Sales_Order_Line__c, solUnits);
        // SOLSet.add(a.Sales_Order_Line__c);
    }
    for(KNDY4__Sales_Order_Line__c newSOL : Trigger.New){
        oldSOL = oMap.get(newSOL.Id);
        if (newSOL.KNDY4__Fulfillment_Source__c != 'Build To Order') { continue; } // don't manage units for sol not built to order
        if(unitMap.isEmpty() || newSOL.KNDY4__Quantity_Ordered__c > unitMap.get(newSOL.Id).size() || !unitMap.containsKey(newSOL.Id)){
            if(newSOL.KNDY4__Status__c == 'Open' && (oldSOL.KNDY4__Quantity_Ordered__c != newSOL.KNDY4__Quantity_Ordered__c || oldSOL.KNDY4__Status__c == 'Draft')){
                Integer numUnitsAlreadyCreated = unitMap.containsKey(newSOL.Id) ? unitMap.get(newSOL.Id).size() : 0;
                Integer numUnitsToCreate = Integer.Valueof(newSOL.KNDY4__Quantity_Ordered__c) - numUnitsAlreadyCreated;
                for(Integer i = 0; i < numUnitsToCreate; i++){
                    SPOC_Quality_Assurance__c newUnit = new SPOC_Quality_Assurance__c();
                    newUnit.Sales_Order_Line__c = newSOL.Id;
                    newUnit.Sales_Order__c = newSOL.KNDY4__Sales_Order__c;
                    newUnit.Work_Order__c = newSOL.KNDY4__Work_Order__c;
                    unitsToInsert.add(newUnit);
                } 
            }
     /*   } 
        if(oldSOL.KNDY4__Status__c == 'Draft' && newSOL.KNDY4__Status__c == 'Open' && (!unitMap.containsKey(newSOL.Id) || newSOL.KNDY4__Quantity_Ordered__c > unitMap.get(newSOL.Id).size())) { // create units under this condition
            // if(SOLSet.contains(newSOL.Id)){ break; }  is this meant to ensure we don't dupliacte units if status is toggled back and forth? If so, adjustment was made with final condition above
            Integer numUnitsAlreadyCreated = unitMap.containsKey(newSOL.Id) ? unitMap.get(newSOL.Id).size() : 0;
            Integer numUnitsToCreate = Integer.Valueof(newSOL.KNDY4__Quantity_Ordered__c) - numUnitsAlreadyCreated;
            for(Integer i = 0; i < numUnitsToCreate; i++){
                SPOC_Quality_Assurance__c newUnit = new SPOC_Quality_Assurance__c ();
                newUnit.Sales_Order_Line__c = newSOL.Id;
                newUnit.Sales_Order__c = newSOL.KNDY4__Sales_Order__c;
                newUnit.Work_Order__c = newSOL.KNDY4__Work_Order__c;
                unitsToInsert.add(newUnit);
            } */
        } else if(oldSOL.KNDY4__Work_Order__c != newSOL.KNDY4__Work_Order__c && newSOL.KNDY4__Work_Order__c != null) { // update units under this condition
            if(!unitMap.containsKey(newSOL.Id)){ continue; } // skid if wo has no sol ref or if no units mapped
            for (SPOC_Quality_Assurance__c unitToUpdate : unitMap.get(newSOL.Id)){
                unitToUpdate.Work_Order__c = newSOL.KNDY4__Work_Order__c;
                unitsToUpdate.add(unitToUpdate);
            }
        } else if(newSOL.KNDY4__Status__c == 'Cancelled' || newSOL.KNDY4__Quantity_Ordered__c < unitMap.get(newSOL.Id).size()){
            if (!unitMap.containsKey(newSOL.Id)) { continue; } // skip if no units mapped
            for (SPOC_Quality_Assurance__c unitToDelete : unitMap.get(newSOL.Id)){
                if(unitToDelete.Work_Order__r.KNDY4__Status__c != 'Cancelled'){ continue;
                } else { unitsToDelete.add(unitToDelete); }
            }
      /*  } else if(oldSOL.KNDY4__Quantity_Ordered__c != newSOL.KNDY4__Quantity_Ordered__c){
            if(!unitMap.containsKey(newSOL.Id)) { continue; } // skip if no units mapped
            else if(newSOL.KNDY4__Quantity_Ordered__c < unitMap.get(newSOL.Id).size()){

            
            }
        }
        
            Rewrote this piece above as # of units will not be linear to # of sales order lines
            Thus, we map all related units above and then just pull them down to re-assign new WO Id
            for(j=0; newSOL.Id != existingUnits[j].Sales_Order_Line__c; j++){
                continue;
            }
            SPOC_Quality_Assurance__c updateUnitWO = existingUnits[j];
            updateUnitWO.Work_Order_c = newSOL.KNDY4_Work_Order__c;
            updateUnit.add(updateUnitWO);
        }
            */
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