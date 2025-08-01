using Toybox.Communications;
using Toybox.Lang;

// SyncDelegate to execute single command via POST request to Home Assistant
//
class HomeAssistantSyncDelegate extends Communications.SyncDelegate {
    private static var syncError as Lang.String or Null;

    // Initialize an instance of this delegate
    public function initialize() {
        SyncDelegate.initialize();
    }

    //! Called by the system to determine if a sync is needed
    public function isSyncNeeded() as Lang.Boolean {
        return true;
    }

    //! Called by the system when starting a bulk sync.
    public function onStartSync() as Void {
        syncError = null;
        
        if (WifiLteExecutionConfirmDelegate.mCommandData == null) {
            syncError = WatchUi.loadResource($.Rez.Strings.WifiLteExecutionDataError) as Lang.String;
            onStopSync();
            return;
        }
        
        var type = WifiLteExecutionConfirmDelegate.mCommandData[:type];
        var data = WifiLteExecutionConfirmDelegate.mCommandData[:data];
        var url;

        switch (type) {
            case "service":
                var service = WifiLteExecutionConfirmDelegate.mCommandData[:service];
                url = Settings.getApiUrl() + "/services/" + service.substring(0, service.find(".")) + "/" + service.substring(service.find(".")+1, service.length());
                var entity_id = "";
                if (data != null) {
                    entity_id = data.get("entity_id");
                    if (entity_id == null) {
                        entity_id = "";
                    }
                }
                performRequest(url, data);
                break;
            case "entity":
                url = WifiLteExecutionConfirmDelegate.mCommandData[:url];
                performRequest(url, data);
                break;
        }
    }

    // Performs a POST request to Hass with a given payload and URL, and calls haCallback
    private function performRequest(url as Lang.String, data as Lang.Dictionary or Null) {
        Communications.makeWebRequest(
            url,
            data, // May include {"entity_id": xxxx} for service calls
            {
                :method  => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type"  => Communications.REQUEST_CONTENT_TYPE_JSON,
                    "Authorization" => "Bearer " + Settings.getApiKey()
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:haCallback)
        );
    }

    //! Handle callback from request
    public function haCallback(code as Lang.Number, data as Null or Lang.Dictionary) as Void {
        Communications.notifySyncProgress(100);
        if (code == 200) {
            syncError = null;
            if (WifiLteExecutionConfirmDelegate.mCommandData[:type].equals("entity")) {
                var callbackMethod = WifiLteExecutionConfirmDelegate.mCommandData[:callback];               
                if (callbackMethod != null) {
                    var d = data as Lang.Array;
                    callbackMethod.invoke(d);
                }
            }
            onStopSync();
            return;
        }

        switch(code) {
            case Communications.NETWORK_REQUEST_TIMED_OUT:
                syncError = WatchUi.loadResource($.Rez.Strings.TimedOut) as Lang.String;
                break;
            case Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE:
                syncError = WatchUi.loadResource($.Rez.Strings.NoJson) as Lang.String;
                syncError = "";
            default:
                var codeMsg = WatchUi.loadResource($.Rez.Strings.UnhandledHttpErr) as Lang.String;
                syncError = codeMsg + code;
                break;
        }

        onStopSync();
    }

    //! Clean up
    public function onStopSync() as Void {
        if (WifiLteExecutionConfirmDelegate.mCommandData[:exit]) {
            System.exit();
        }
        
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(syncError);
    }
}
