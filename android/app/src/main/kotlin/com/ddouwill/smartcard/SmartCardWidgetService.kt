package com.ddouwill.smartcard

import android.content.Intent
import android.widget.RemoteViewsService

class SmartCardWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return SmartCardWidgetFactory(applicationContext)
    }
}
