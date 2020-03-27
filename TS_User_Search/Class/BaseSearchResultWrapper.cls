global with sharing class BaseSearchResultWrapper {
    private static final Set<String> MAILING_ADDRESS = new Set<String> {
        'mailingstreet', 'mailingcity', 'mailingstate', 'mailingpostalcode', 'mailingcountry', 
        'mailinglatitude', 'mailinglongitude', 'mailinggeocodeaccuracy', 'mailingaddress'
    };
    private static final Set<String> OTHER_ADDRESS = new Set<String> {
        'otherstreet', 'othercity', 'otherstate', 'otherpostalcode', 'othercountry', 
        'otherlatitude', 'otherlongitude', 'othergeocodeaccuracy', 'otheraddress'
    };
    private static final Set<String> BILLING_ADDRESS = new Set<String> {
        'billingstreet', 'billingcity', 'billingstate', 'billingpostalcode', 'billingcountry', 
        'billinglatitude', 'billinglongitude', 'billinggeocodeaccuracy', 'billingaddress'
    };
    private static final Set<String> SHIPPING_ADDRESS = new Set<String> {
        'shippingstreet', 'shippingcity', 'shippingstate', 'shippingpostalcode', 'shippingcountry', 
        'shippinglatitude', 'shippinglongitude', 'shippinggeocodeaccuracy', 'shippingaddress'
    };
    private static final Set<String> LEAD_ADDRESS = new Set<String> {
        'street', 'city', 'state', 'postalcode', 'country', 'latitude', 'longitude', 'geocodeaccuracy', 'address'
    };

    global String objName { get; private set; }

    global BaseSearchController pageController { get; private set; }

    global Boolean isCreateable { get; private set; }
    global Boolean isUpdateable { get; private set; }
    global Boolean isDeletable { get; private set; }
    global Boolean isSortable { get; set; }

    global List<FieldInfo> fields { get; set; }
    global Boolean hasRecords { get { return (records != null && !records.isEmpty()); } }
    global List<TS_SearchResultItemWrapper> records { get; private set; }
    global List<SObject> recordList {get; set;}

    private Map<Id, Boolean> selMap = new Map<Id, Boolean>();

    global Map<String, String> addButtonParam { get; set; }
    global Map<String, Set<String>> fieldMap { get; set; }
    
    global class FieldInfo {
        public String label { get; private set; }
        public String name { get; private set; }
        public Boolean isUpdateable { get; private set; }
        public Boolean isRequired { get; private set; }

        public Boolean isName { get; private set; }
        public Boolean isGeoLocation { get; private set; }
        public Boolean isAddress { get; private set; }
        public Boolean isOther { get { return !(isName | isGeoLocation | isAddress | isCommand); } }
        public Boolean isPersonName { get; private set; }
        public Boolean isSortable { get; private set; }
        public Boolean isRelationship { get; private set; }
        public Boolean isCommand { get; private set; }
        public Boolean isLast { get; private set; }
        public Boolean isHidden { get; private set; }

        public String f_latitude { get; private set; }
        public String f_longitude { get; private set; }
        public String f_country { get; private set; }
        public String f_postalCode { get; private set; }
        public String f_state { get; private set; }
        public String f_city { get; private set; }
        public String f_street { get; private set; }

        public String sortIcon { get; set; }
        
        public Boolean isDisplay { get; set; }

        public List<String> queryFields { get; private set; }

        public FieldInfo(
            Map<String, Schema.sObjectField> fldMap, 
            String fieldNameKey, 
            Boolean isRelation, 
            String relName,
            List<String> readOnlyFields,
            List<String> invalidLinkFields,
            List<String> hiddenFields
        ) {
            queryFields = new List<String>();
            sortIcon = '';
            Schema.DescribeFieldResult dfr = fldMap.get(fieldNameKey.removeStart(relName)).getDescribe();
            String fieldName = dfr.getName().toLowerCase();
            label = dfr.getLabel();
            name = fieldNameKey;
            isUpdateable = dfr.isUpdateable() && (readOnlyFields == null || !readOnlyFields.Contains(fieldName));
            isHidden = hiddenFields != null && hiddenFields.Contains(fieldName);
            isSortable = dfr.isSortable();
            isRelationship = isRelation;
            isName = dfr.isNameField() && (invalidLinkFields == null || !invalidLinkFields.Contains(fieldName));
            isPersonName = (isName && fldMap.get('firstname') != null && fldMap.get('lastname') != null);
            if (isPersonName) {
                isUpdateable = (
                    fldMap.get('firstname').getDescribe().isUpdateable() & 
                    fldMap.get('lastname').getDescribe().isUpdateable() & 
                    (!fldMap.containsKey('salutation') || fldMap.get('salutation').getDescribe().isUpdateable())
                );
                queryFields.add('name');
                queryFields.add('firstname');
                queryFields.add('lastname');
                if (fldMap.containsKey('salutation')) {
                    queryFields.add('salutation');
                }
            }
            isAddress = (dfr.getType() == Schema.DisplayType.Address);
            if (isAddress) {
                Set<String> AddressSet = null;
                if (MAILING_ADDRESS.contains(fieldName)) {
                    AddressSet = MAILING_ADDRESS;
                }
                if (OTHER_ADDRESS.contains(fieldName)) {
                    AddressSet = OTHER_ADDRESS;
                }
                if (BILLING_ADDRESS.contains(fieldName)) {
                    AddressSet = BILLING_ADDRESS;
                }
                if (SHIPPING_ADDRESS.contains(fieldName)) {
                    AddressSet = SHIPPING_ADDRESS;
                }
                if (LEAD_ADDRESS.contains(fieldName)) {
                    AddressSet = LEAD_ADDRESS;
                }
                isUpdateable = true;
                for (String fld : AddressSet) {
                    if (fld.endsWith('country')) {
                        f_country = (isRelation ? relName : '') + fld;
                    } else if (fld.endsWith('postalcode')) {
                        f_postalCode = (isRelation ? relName : '') + fld;
                    } else if (fld.endsWith('state')) {
                        f_state = (isRelation ? relName : '') + fld;
                    } else if (fld.endsWith('city')) {
                        f_city = (isRelation ? relName : '') + fld;
                    } else if (fld.endsWith('street')) {
                        f_street = (isRelation ? relName : '') + fld;
                    } else {
                        continue;
                    }
                    isUpdateable &= fldMap.get(fld).getDescribe().isUpdateable();
                }
                queryFields.add(f_country);
                queryFields.add(f_postalCode);
                queryFields.add(f_state);
                queryFields.add(f_city);
                queryFields.add(f_street);
                isSortable = true;
            }
            isGeoLocation = (dfr.getType() == Schema.DisplayType.Location);
            if (isGeoLocation) {
                f_latitude = name.replace('__c', '__latitude__s');
                f_longitude = name.replace('__c', '__longitude__s');
                isUpdateable = (
                    fldMap.get(f_latitude.removeStart(relName)).getDescribe().isUpdateable() & 
                    fldMap.get(f_longitude.removeStart(relName)).getDescribe().isUpdateable()
                );
                queryFields.add(f_latitude);
                queryFields.add(f_longitude);
                isSortable = true;
            }
            if (dfr.getType() == Schema.DisplayType.Reference) {
                queryFields.add((isRelation ? relName : '') + dfr.getRelationshipName() + '.name');
            }
            if (queryFields.isEmpty()) {
                queryFields.add(name);
            }
            isRequired = !(dfr.isNillable() || (dfr.getType() == Schema.DisplayType.Boolean));
            if (isRelation) {
                isUpdateable = false;
            }
            isCommand = false;
        }

        public FieldInfo(String header, String value, Boolean isLast) {
            label = header;
            name = value;
            isUpdateable = false;
            isRequired = false;
            isName = false;
            isGeoLocation = false;
            isAddress = false;
            isPersonName = false;
            isSortable = false;
            isRelationship = false;
            isCommand = true;
            this.isLast = isLast;
        }
    }

    private String relationIdField;
    private List<String> fieldNameList;
    global String fieldsetName {get; set;}
    global List<SelectOption> fieldsetNames { get; set; }
    global BaseSearchResultWrapper(
        BaseSearchController pageController, 
        Schema.DescribeSObjectResult objDescribeResult, 
        Schema.DescribeSObjectResult addDescribeResult, 
        String addItemName,
        String conditionFieldSet,
        List<String> primaryFieldNameList
    ) {
        this.pageController = pageController;
        this.objName = objDescribeResult.getName();
        this.relationIdField = addItemName.toLowerCase();
        this.isCreateable = objDescribeResult.isCreateable();
        this.isUpdateable = objDescribeResult.isUpdateable();
        this.isDeletable = objDescribeResult.isDeletable();
        this.records = new List<TS_SearchResultItemWrapper>();
        this.recordList = new List<SObject>();

        this.fieldNameList = new List<String> { 'Name' };
        if (primaryFieldNameList != null) {
            fieldNameList.addAll(primaryFieldNameList);
        }
        this.isSortable = false;
        
        Map<String, Schema.FieldSet> fieldSets = objDescribeResult.FieldSets.getMap();
        this.fieldsetNames = new List<SelectOption>();
        for (String fs : fieldSets.keySet()) {
        	if (fs == conditionFieldSet) {
        		continue;
        	}
            this.fieldsetNames.add(new SelectOption(fs, fieldSets.get(fs).getLabel()));
            
            if (String.isEmpty(this.fieldsetName)) {
                this.fieldsetName = fs;
            }
        }
    }
    global void setDisplay() {
        for (FieldInfo fi : this.fields) {
            if (String.isEmpty(fi.name)) {
                fi.isDisplay = true;
            } else {
                if (fi.isCommand || this.fieldMap.get(fi.name).contains(this.fieldsetName)) {
                    fi.isDisplay = true;
                } else {
                    fi.isDisplay = false;
                }
            }
        }
    }

    private String getNameKey(String fieldNameKey, String relName) {
        if (fieldNameKey.endsWith('__latitude__s') || fieldNameKey.endsWith('__longitude__s')) {
            return fieldNameKey.replaceFirst('__(latitude|longitude)__s', '__c');
        }
        String fieldName = fieldNameKey.removeStart(relName);
        if (fieldName == 'LastName' || fieldName == 'FirstName' || fieldName == 'Salutation') {
            return relName + 'name';
        }
        if (MAILING_ADDRESS.contains(fieldName)) {
            return relName + 'mailingaddress';
        }
        if (OTHER_ADDRESS.contains(fieldName)) {
            return relName + 'otheraddress';
        }
        if (BILLING_ADDRESS.contains(fieldName)) {
            return relName + 'billingaddress';
        }
        if (SHIPPING_ADDRESS.contains(fieldName)) {
            return relName + 'shippingaddress';
        }
        if (LEAD_ADDRESS.contains(fieldName)) {
            return relName + 'address';
        }
        return fieldNameKey;
    }

    private String addFieldInfo(
        Map<String, Schema.sObjectField> fldMap1, 
        Map<String, Schema.sObjectField> fldMap2, 
        String fieldName, 
        String relName, 
        Set<String> fnSet
    ) {
        Boolean isRelation = (String.isNotEmpty(relName) ? fieldName.startsWithIgnoreCase(relName) : false);
        String fieldNameKey = getNameKey(fieldName.toLowerCase(), isRelation ? relName : '');
        
        if (fnSet.contains(fieldNameKey) || (isRelation && fldMap2 == null)) {
            return fieldNameKey;
        }

        Map<String, Schema.sObjectField> fldMap = isRelation ? fldMap2 : fldMap1;
        if (fldMap.keySet().contains(fieldNameKey.removeStart(relName))) {
            this.fields.add(new FieldInfo(fldMap, fieldNameKey, isRelation, relName, this.pageController.getReadonlyFieldList(), this.pageController.getInvalidLinkFieldList(), this.pageController.getHiddenFieldList()));
            fnSet.add(fieldNameKey);
        }
        return fieldNameKey;
    }

    public void setFieldInfo(Schema.DescribeSObjectResult objDescribeResult, Schema.DescribeSObjectResult addDescribeResult) {
        this.fieldMap = new Map<String, Set<String>>();

        this.fields = new List<FieldInfo>();
        Map<String, Schema.sObjectField> fldMap1 = objDescribeResult.Fields.getMap();
        Map<String, Schema.sObjectField> fldMap2 = (addDescribeResult == null ? null : addDescribeResult.Fields.getMap());
        String relName = '';
        Set<String> fnSet = new Set<String>();
        Map<String, Schema.FieldSet> fieldSetMap = objDescribeResult.FieldSets.getMap();
        for (String fieldName : fieldNameList) {
            String fn = addFieldInfo(fldMap1, fldMap2, fieldName, relName, fnSet);
            this.fieldMap.put(fn, new Set<String>(fieldSetMap.keySet()));
        }
        if (fldMap1.keySet().contains(relationIdField)) {
            relName = fldMap1.get(relationIdField).getDescribe().getRelationshipName();
            relName = (String.isNotEmpty(relName) ? relName.toLowerCase() + '.' : '');
        }
        for (String fsn : fieldSetMap.keySet()) {
            if (String.isEmpty(fieldsetName)) {
                this.fieldsetName = fsn.toLowerCase();
            }
            Schema.FieldSet fs = fieldSetMap.get(fsn.toLowerCase());
            for (Schema.FieldSetMember fsm : fs.getFields()) {
                String fn = addFieldInfo(fldMap1, fldMap2, fsm.getFieldPath(), relName, fnSet);
                
                Set<String> fsSet;
                if (this.fieldMap.containsKey(fn)) {
                    fsSet = this.fieldMap.get(fn);
                } else {
                    fsSet = new Set<String>();
                }
                fsSet.add(fsn.toLowerCase());
                this.fieldMap.put(fn, fsSet);
            }
        }
        if (addButtonParam != null) {
            if (String.isNotEmpty(addButtonParam.get('header1')) || String.isNotEmpty(addButtonParam.get('value1'))) {
                this.fields.add(new FieldInfo(addButtonParam.get('header1'), addButtonParam.get('value1'), false));
            }
        }
        if (addButtonParam != null) {
            if (String.isNotEmpty(addButtonParam.get('header2')) || String.isNotEmpty(addButtonParam.get('value2'))) {
                this.fields.add(new FieldInfo(addButtonParam.get('header2'), addButtonParam.get('value2'), true));
            }
        }
    }

    public void clearSelect() {
        selMap = new Map<Id, Boolean>();
    }

    public void pushSelect() {
        for (TS_SearchResultItemWrapper item : records) {
            selMap.put(item.objEdit.id, item.isSelected);
        }
    }

    public void setResult(List<SObject> resultList) {
    	this.recordList = resultList;
        records.clear();
        for (SObject obj : resultList) {
            TS_SearchResultItemWrapper item = new TS_SearchResultItemWrapper(obj, relationIdField, Schema.getGlobalDescribe().get(objName), addButtonParam);
            if (selMap.keySet().contains(item.objEdit.id)) {
                item.isSelected = selMap.get(item.objEdit.id);
            }
            records.add(item);
        }
        setDisplay();
    }

    public List<SObject> getItemList() {
        List<SObject> ret = new List<SObject>();
        for (TS_SearchResultItemWrapper item : records) {
            ret.add(item.objEdit);
        }
        return ret; 
    }

    public List<Id> getSelectedIdList() {
        List<Id> ret = new List<Id>();
        pushSelect();
        for (Id selId : selMap.keySet()) {
            if (selMap.get(selId)) {
                ret.add(selId);
            }
        }
        return ret; 
    }

    global Map<String, Map<String, String>> commandButtonMap { get; private set; }
    global Boolean hasButtons { get { return (commandButtonMap != null && !commandButtonMap.isEmpty()); } }

    public void addCommandButton(String componentId, Map<String, String> addParams) {
        if (commandButtonMap == null) {
            commandButtonMap = new Map<String, Map<String, String>>();
        }
        commandButtonMap.put(componentId, addParams);
    }
}