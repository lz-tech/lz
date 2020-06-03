global with sharing virtual class BaseSearchController extends ParentController {
    global BaseSearchResultWrapper result { get; private set; }
    global BaseSearchConditionWrapper condition { get; private set; }

    global Integer curPage { get; private set; }
    global Integer maxPage { get; private set; }
    global Integer stRow { get { return (limitSize != null && limitSize > 0) ? ((curPage - 1) * limitSize + 1) : null; } }
    global Integer edRow { get { return (limitSize != null && limitSize > 0) ? Math.min(curPage * limitSize, rowCount) : null; } }
    global Integer rowCount { get; private set; }
    global List<Integer> naviButtons { get; private set; }
    global Integer naviBase { get; set; }
    global String infoArrayJSON { get; set; }

    global String infoMessage { get; private set; }

    global ColWidthInfo colInfo {
        get {
            if (colInfoMap == null) {
                colInfoMap = (Map<String, ColWidthInfo>)getCache('ColInfo');
            }
            if (colInfoMap != null && colInfoMap.keySet().contains(CACHE_KEY)) {
                return colInfoMap.get(CACHE_KEY);
            }
            return new ColWidthInfo();
        }
    }
    private transient Map<String, ColWidthInfo> colInfoMap = null;
    private String CACHE_KEY = null;

    private String whereString = null;
    private String sortFields = null;
    private Integer limitSize = -1;
    private Integer pageOffset = -1;

    protected List<SObject> records { get { return result.getItemList(); }  }
    protected List<Id> selectedIds { get { return result.getSelectedIdList(); } }

    private class DescribeInfo {
        public String objName { get; private set; }
        public String addName { get; private set; }

        private transient Schema.DescribeSObjectResult objDescribeResult = null;
        private transient Schema.DescribeSObjectResult addDescribeResult = null;

        DescribeInfo(String objName, String addName) {
            this.objName = objName.toLowerCase();
            this.addName = (addName == null ? null : addName.toLowerCase());
        }

        public Schema.DescribeSObjectResult getObjDescribeResult() {
            if (objDescribeResult == null) {
                objDescribeResult = Schema.getGlobalDescribe().get(objName).getDescribe();
            }
            return objDescribeResult;
        }

        public Schema.DescribeSObjectResult getAddDescribeResult() {
            if (addDescribeResult == null && String.isNotEmpty(addName)) {
                addDescribeResult = Schema.getGlobalDescribe().get(addName).getDescribe();
            }
            return addDescribeResult;
        }
    }

    private class SortOrderInfo {
        public String sortKey;
        public String sortDir;
    }
    private class ColumnInfo {
        public String name;
        public Integer width;
    }
    public class ColWidthInfo {
        public List<String> nameList;
        public Map<String, Integer> widthMap;
        public String nameListJSON { 
            get {
                return JSON.serialize(nameList);
            } 
        }
        public String widthMapJSON {
            get {
                return JSON.serialize(widthMap);
            } 
        }
        public ColWidthInfo() {
            nameList = new List<String>();
            widthMap = new Map<String, Integer>();
        }
    }

    private DescribeInfo descInfo;

    global BaseSearchController(
        Schema.DescribeSObjectResult objDescribeResult,
        Schema.DescribeSObjectResult addDescribeResult, 
        String addItemName,
        String conditionFieldSetName,
        List<String> primaryFieldNameList,
        Map<String, String> addButtonParam
    ) {
        this(
            objDescribeResult.getName(),
            addDescribeResult == null ? null : addDescribeResult.getName(),
            addItemName, 
            conditionFieldSetName,
            primaryFieldNameList,
            addButtonParam
        );
    }
    
    global BaseSearchController(
        String objName,
        String addObjName, 
        String addItemName,
        String conditionFieldSetName,
        List<String> primaryFieldNameList,
        Map<String, String> addButtonParam
    ) {
        descInfo = new DescribeInfo(objName, addObjName);
        Schema.DescribeSObjectResult objDescribeResult = descInfo.getObjDescribeResult();
        Schema.DescribeSObjectResult addDescribeResult = descInfo.getAddDescribeResult();
        CACHE_KEY = this.toString().split(':')[0];

        condition = new BaseSearchConditionWrapper(this, objDescribeResult, conditionFieldSetName);
        
        result = new BaseSearchResultWrapper(this, objDescribeResult, addDescribeResult, addItemName, conditionFieldSetName, primaryFieldNameList);
        result.addButtonParam = addButtonParam;
        result.setFieldInfo(objDescribeResult, addDescribeResult);
        result.setDisplay();
        
        rowCount = 0;
        infoMessage = null;
        naviButtons = new List<Integer>();
    }

    private transient Cache.SessionPartition sessionPart = null;

    private Object getCache(String key) {
        if (sessionPart == null) {
            sessionPart = Cache.Session.getPartition('local.SearchParamPartition');
        }
        return sessionPart.get(key);
    }

    private String createQueryString() {
        Set<String> queryFields = new Set<String>();
        for (BaseSearchResultWrapper.FieldInfo flInfo : result.fields) {
            if (!flInfo.isCommand) {
                String key = flInfo.name.toLowerCase();
                queryFields.add(key);
                for (String fnam : flInfo.queryFields) {
                    queryFields.add(fnam.toLowerCase());
                }
            }
        }

        String soql = 'select Id';
        for (String key1 : queryFields) {
            if (key1 == 'Id') {
                continue;
            }
            soql += (', ' + key1);
        }
        soql += ' from ';
        soql += result.objName;
        return soql;
    }

    protected void addCommandButton(String componentId, Map<String, String> addParams) {
        result.addCommandButton(componentId, addParams);
    }

    protected String getQueryString(String conditionExpression) {
        return getQueryString(conditionExpression, null, -1);
    }

    private String getQueryString(String conditionExpression, List<String> fieldList, Integer maxRows) {
        whereString = conditionExpression;
        sortFields = '';
        if (fieldList != null) {
            for (String f : fieldList) {
                if (String.isNotEmpty(sortFields)) {
                    sortFields += ', ';
                }
                sortFields += f;
            }
        }
        limitSize = (maxRows == null ? -1 : maxRows);
        return getOrderedQueryString();
    }

    private String getOrderedQueryString() {
        Schema.DescribeSObjectResult objDescribeResult = descInfo.getObjDescribeResult();
        Schema.DescribeSObjectResult addDescribeResult = descInfo.getAddDescribeResult();
        result.setFieldInfo(objDescribeResult, addDescribeResult);

        String orderString = getSortKey();
        String ret = createQueryString();

        if (String.isNotEmpty(whereString)) {
            ret += (' ' + whereString);
        }
        orderString += ((String.isNotEmpty(orderString) & String.isNotEmpty(sortFields) ? ', ' : '') + sortFields);
        if (String.isNotEmpty(orderString)) {
            ret += (' order by ' + orderString + ', Id');
        } else {
            ret += (' order by Id');
        }
        if (limitSize > 0) {
            ret += (' limit ' + limitSize);
            if (pageOffset > 0) {
                ret += (' offset ' + (pageOffset * limitSize));
            }
        }
        return ret;
    }

    private void setSortKey(String sortColumn) {
        Map<String, SortOrderInfo> sortInfoMap = (Map<String, SortOrderInfo>)getCache('SortKey');
        SortOrderInfo sortInfo = null;
        if (sortInfoMap != null) {
            sortInfo = sortInfoMap.get(CACHE_KEY);
        } else {
            sortInfoMap = new Map<String, SortOrderInfo>();
        }
        if (sortInfo == null) {
            sortInfo = new SortOrderInfo();
        }
        if (String.isNotEmpty(sortColumn)) {
            if (sortInfo.sortKey == sortColumn && sortInfo.sortDir == 'ASC') {
                sortInfo.sortDir = 'DESC';
            } else {
                sortInfo.sortDir = 'ASC';
            }
            sortInfo.sortKey = sortColumn;
        } else {
            sortInfo.sortKey = '';
            sortInfo.sortDir = '';
        }
        sortInfoMap.put(CACHE_KEY, sortInfo);
        sessionPart.put('SortKey', sortInfoMap);
    }

    private String getSortKey() {
        String sortOrder = '';
        Map<String, SortOrderInfo> sortInfoMap = (Map<String, SortOrderInfo>)getCache('SortKey');
        SortOrderInfo sortInfo = null;
        if (sortInfoMap != null) {
            sortInfo = sortInfoMap.get(CACHE_KEY);
        }
        if (sortInfo == null) {
            sortInfo = new SortOrderInfo();
        }
        for (BaseSearchResultWrapper.FieldInfo fld : result.fields) {
            if (fld.name == sortInfo.sortKey) {
                if (fld.isSortable) {
                    String dir = '';
                    if (sortInfo.sortDir == 'DESC') {
                        fld.sortIcon = '↓';
                        dir = ' DESC NULLS LAST';
                    } else {
                        fld.sortIcon = '↑';
                        dir = ' ASC NULLS FIRST';
                    }

                    for (String fnam : fld.queryFields) {
                        sortOrder += (String.isEmpty(sortOrder) ? '' : ', ');
                        sortOrder += (fnam + dir);
                    }
                    continue;
                }
            }
            fld.sortIcon = '';
        }
        return sortOrder;
    }

    protected void setResult(List<SObject> resultList) {
        result.isSortable = false;
        result.setResult(resultList);
    }

    protected void execQuery(String conditionExpression, List<String> fieldList, Integer maxRows) {
        setSortKey('');
        pageOffset = -1;
        result.clearSelect();
        result.isSortable = true;
        
    	conditionExpression = condition.getConditionExpression(conditionExpression);
        result.setResult(Database.query(getQueryString(conditionExpression, fieldList, maxRows)));
        //result.setDisplay();
        AggregateResult[] ar = Database.query('select count(Id) from ' + result.objName + ' ' + whereString);
        rowCount = (Integer)ar[0].get('expr0');
        if (limitSize > 0 && rowCount > limitSize + 2000) {
            infoMessage = '検索結果が ' + (limitSize + 2000) + ' 件以上存在するため、すべてを表示できません。検索条件を絞ってください。';
            rowCount = limitSize + 2000;
        } else {
            infoMessage = null;
        }
        curPage = 1;
        if (limitSize > 0) {
            Integer divmod = Math.mod(rowCount, limitSize);
            if (divmod == 0) {
                maxPage = rowCount / limitSize;
            } else {
                maxPage = (rowCount + (limitSize - divmod)) / limitSize;
            }
        }
        naviBase = curPage;
        setNaviButtons();
    }

    protected void execQuery() {
        pageOffset = -1;
        result.setResult(Database.query(getOrderedQueryString()));
    }
    
    protected void saveRecords() {
    	try {
	    	FlgManagement.isDmlExtention = false; // コンポーネントからDML発行する対応
	        update result.recordList;
	        infoMessage = '保存しました。';
    	} catch (Exception ex) {
    		infoMessage = '保存できませんでした。\r\n';
    		infoMessage = infoMessage + ex.getMessage();
    	}
    }

    // 検索
    global virtual PageReference doSearch() {
        execQuery('', null, -1);
        return null;
    }

    protected String getRefId() {
        String cmdId = null;
        Map<String, String> params = ApexPages.currentPage().getParameters();
        for (String key : params.keySet()) {
            if (key.endsWith(':cmdbtn1') || key.endsWith(':cmdbtn2')) {
                cmdId = key;
            }
        }
        if (String.isEmpty(cmdId)) {
            return '';
        }
        return params.get(cmdId.left(cmdId.length() - 7) + 'refId');
    }

    global virtual PageReference doCommand1() {
        return null;
    }

    global virtual PageReference doCommand2() {
        return null;
    }

    private void setNaviButtons() {
        naviButtons = new List<Integer>();
        if (maxPage > 1) {
            if (maxPage <= 5) {
                for (Integer idx = 1; idx <= maxPage; idx++) {
                    naviButtons.add(idx);
                }
            } else {
                Integer firstButton = naviBase - 2;
                if (firstButton < 1) {
                    firstButton = 1;
                    naviBase = 3;
                } else if (firstButton > maxPage - 4) {
                    firstButton = maxPage - 4;
                    naviBase = maxPage - 2;
                }
                for (Integer idx = 0; idx < 5; idx++) {
                    naviButtons.add(firstButton + idx);
                }
            }
        }
    }
    // ソート
    global PageReference ChangeFieldSet() {
        result.pushSelect();
        result.setResult(result.recordList);
        result.setDisplay();
        return null;
    }

    // ソート
    global PageReference doSort() {
        setSortKey(ApexPages.currentPage().getParameters().get('sortColumn'));
        pageOffset = -1;
        curPage = 1;
        result.pushSelect();
        result.setResult(Database.query(getOrderedQueryString()));
        //result.setDisplay();
        naviBase = curPage;
        setNaviButtons();
        return null;
    }

    // ページ移動
    global PageReference movePage() {
        String pageNum = ApexPages.currentPage().getParameters().get('pageNum');
        if (String.isNotEmpty(pageNum)) {
            curPage = Integer.valueOf(pageNum);
            pageOffset = curPage - 1;
        }
        result.pushSelect();
        result.setResult(Database.query(getOrderedQueryString()));
        //result.setDisplay();
        naviBase = curPage;
        setNaviButtons();
        return null;
    }

    global PageReference refreshNavi() {
        String grp = ApexPages.currentPage().getParameters().get('grp');
        if (grp == 'prev') {
            naviBase = Math.max(1, naviBase - 5);
        } else {
            naviBase = Math.min(maxPage, naviBase + 5);
        }
        setNaviButtons();
        return null;
    }

    global PageReference saveColumnWidth() {
        List<ColumnInfo> infoArray = (List<ColumnInfo>)JSON.deserialize(infoArrayJSON, List<ColumnInfo>.class);
        if (infoArray == null || infoArray.isEmpty()) {
            return null;
        }

//      Cache.SessionPartition sessionPart = Cache.Session.getPartition('local.SearchParamPartition');
//      Map<String, ColWidthInfo> colInfoMap = (Map<String, ColWidthInfo>)sessionPart.get('ColInfo');
        colInfoMap = (Map<String, ColWidthInfo>)getCache('ColInfo');
        ColWidthInfo colInfo = null;
        if (colInfoMap != null) {
            colInfo = colInfoMap.get(CACHE_KEY);
        } else {
            colInfoMap = new Map<String, ColWidthInfo>();
        }
        if (colInfo == null || infoArray.size() > 1) {
            colInfo = new ColWidthInfo();
        }

        if (colInfo.nameList.isEmpty()) {
            for (ColumnInfo info : infoArray) {
                colInfo.nameList.add(info.name);
                colInfo.widthMap.put(info.name, info.width);
            }
        } else {
            colInfo.widthMap.put(infoArray[0].name, infoArray[0].width);
        }

        colInfoMap.put(CACHE_KEY, colInfo);
        sessionPart.put('ColInfo', colInfoMap);

        return null;
    }
    
    /*
           * 編集不可とする項目を取得
     * @return 編集不可とする項目のリスト 具象クラスにて下記方法で取得すること
            *         「Schema.SObjectType.<オブジェクト型>.fields.<項目API名>.getName()」
     */
    global virtual List<String> getReadonlyFieldList() {
        return null;
    }
    
	/*
	  *リンク無効化項目を取得
     * @return リンク無効化項目のリスト 具象クラスにて下記方法で取得すること
	  *         「Schema.SObjectType.<オブジェクト型>.fields.<項目API名>.getName()」
     */
    global virtual List<String> getInvalidLinkFieldList() {
        return null;
    }
    
    /*
           * 非表示項目を取得
     * @return 非表示項目のリスト 具象クラスにて下記方法で取得すること
            *         「Schema.SObjectType.<オブジェクト型>.fields.<項目API名>.getName()」
     */
    global virtual List<String> getHiddenFieldList() {
        return null;
    }
}