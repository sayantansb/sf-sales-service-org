/**
 * Created by sayantan.sb on 18.04.22.
 */

trigger OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete) {
    if (!System.isBatch()) {
        System.debug('OpportunityTrigger for Opportunity (not batch and not future) :: begins');
        OpportunityTriggerHandler handler = new OpportunityTriggerHandler();

        if (Trigger.isInsert) {
            System.debug('OpportunityTrigger for insert :: begins');
            if (Trigger.isBefore) {
                System.debug('isBefore execution :: begins');
                handler.OnBeforeInsert(trigger.New);
                System.debug('isBefore execution :: ends');
            } else {
                System.debug('isAfter execution :: begins');
                handler.OnAfterInsert(trigger.New);
                System.debug('isAfter execution :: ends');
            }
            System.debug('OpportunityTrigger for insert :: ends');
        } else if (Trigger.isUpdate) {
            System.debug('OpportunityTrigger for update :: begins');

            if (Trigger.isBefore) {
                System.debug('isBefore execution :: begins');
                handler.OnBeforeUpdate(trigger.New, trigger.Old, Trigger.NewMap, Trigger.OldMap);
                System.debug('isBefore execution :: ends');
            } else {
                System.debug('isAfter execution :: begins');
                handler.OnAfterUpdate(trigger.New, trigger.Old, Trigger.NewMap, Trigger.OldMap);
                System.debug('isAfter execution :: ends');
            }

            System.debug('OpportunityTrigger for update :: ends');
        }
    }
}