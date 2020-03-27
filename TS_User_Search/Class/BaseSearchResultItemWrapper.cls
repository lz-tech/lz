public with sharing class BaseSearchResultItemWrapper {
    public Boolean isSelected { get; set; }
    public SObject objEdit { get; private set; }
    public transient SObject objDisp { get; private set; }
    public transient Boolean isEmptyRelation { get; private set; }

    public BaseSearchResultItemWrapper(SObject obj, String relationIdField, Schema.SObjectType targetType, Map<String, String> addButton) {
        isSelected = false;
        objDisp = obj;
        objEdit = targetType.newSObject(objDisp.Id);
        isEmptyRelation = (String.isNotEmpty(relationIdField) && obj.get(relationIdField) == null);
    }
}