global with sharing class BaseSearchResultController {
    private static final Integer COL_WIDTH_DEF = 96;

    global BaseSearchResultWrapper resultWrapper { get; set; }
    global Boolean allCheck { get { return false; } set; }
    global Integer colWidthDef { get { return COL_WIDTH_DEF; } }

    global BaseSearchController pageController {
        get {
            return (resultWrapper == null ? null : resultWrapper.pageController);
        }
    }
    global Boolean isSortable {
        get {
            return isSortable & (resultWrapper == null ? false : resultWrapper.isSortable);
        }
        set;
    }
    global Boolean hasButtons { 
        get { 
            return (resultWrapper != null && resultWrapper.hasButtons); 
        } 
    }
    global String infoMessage {
        get {
            return (pageController == null ? null : pageController.infoMessage);
        }
    }

    global Component.Apex.outputPanel commandButtonList {
        get {
            Component.Apex.outputPanel buttons = new Component.Apex.outputPanel( layout = 'none' );
            if (hasButtons) {
                Map<String, Map<String, String>> commandButtonMap = resultWrapper.commandButtonMap;
                for (String key : commandButtonMap.keySet()) {
                    Map<String, String> addParams = commandButtonMap.get(key);
                    Component.Apex.commandButton addButton = new Component.Apex.commandButton( id = key );
                    for (String attr : addParams.keySet()) {
                        if (attr == 'action') {
                            addButton.expressions.action = '{!pageController.' + addParams.get(attr) + '}';
                        } else if (attr == 'value') {
                            addButton.value = addParams.get(attr);
                        } else if (attr == 'reRender') {
                            addButton.reRender = new Set<String>(addParams.get(attr).split(','));
                        } else if (attr == 'oncomplete') {
                        	addButton.oncomplete = addParams.get(attr);
                        }
                    }
                    buttons.childComponents.add(addButton);
                }
            }
            return buttons;
        } 
    }
}