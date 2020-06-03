global with sharing class BaseSearchConditionWrapper {
    global BaseSearchController pageController { get; private set; }
    global String fieldsetName { get; private set; }
    global List<SearchConditionInfo> conditionList { get; set; }
    
    global BaseSearchConditionWrapper(
        BaseSearchController pageController, 
        Schema.DescribeSObjectResult objDescribeResult,
        String fieldsetName
    ) {
        this.pageController = pageController;
        this.fieldsetName = fieldsetName;
        
        this.conditionList = new List<SearchConditionInfo>();
        Schema.FieldSet conditionFieldSet = objDescribeResult.FieldSets.getMap().get(fieldsetName);
        for (Schema.FieldSetMember fsm : conditionFieldSet.getFields()) {
            this.conditionList.add(new SearchConditionInfo(fsm.getLabel(), fsm.getFieldPath().toLowerCase()));
        }
    }
    
    global String getConditionExpression(String conditionExpression) {
        for (SearchConditionInfo con : this.conditionList) {
            if (String.isNotEmpty(con.conditionValue)) {
                if (String.isEmpty(conditionExpression)) {
                    conditionExpression = 'where ';
                } else {
                    conditionExpression += ' and ';
                }
    
                conditionExpression += con.conditionName + ' like \'%' + con.conditionValue + '%\' ';
            }
        }
        return conditionExpression;
    }
    
    global class SearchConditionInfo {
        public String conditionLabel { get; set; }
        public String conditionValue { get; set; }
        public String conditionName { get; set; }
        
        public SearchConditionInfo(String label, String Name) {
            this.conditionLabel = label;
            this.conditionName = Name;
            this.conditionValue = '';
        }
    }
}