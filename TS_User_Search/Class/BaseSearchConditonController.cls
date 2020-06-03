global with sharing class BaseSearchConditonController {    
    global BaseSearchConditionWrapper conditionWrapper { get; set; }

    global BaseSearchController pageController {
        get {
            return (conditionWrapper == null ? null : conditionWrapper.pageController);
        }
    }
    
    global BaseSearchConditonController() {
    }
}