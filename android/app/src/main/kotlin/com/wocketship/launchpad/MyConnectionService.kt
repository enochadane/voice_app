package com.wocketship.launchpad

import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.TelecomManager
import android.util.Log

class MyConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: android.telecom.PhoneAccountHandle,
        request: ConnectionRequest
    ): Connection {
        Log.d("MyConnectionService", "📞 Incoming call received")
        val connection = MyConnection()
        connection.setConnectionProperties(Connection.PROPERTY_SELF_MANAGED)
        connection.setAddress(request.address, TelecomManager.PRESENTATION_ALLOWED)
        connection.setRinging()
        return connection
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: android.telecom.PhoneAccountHandle,
        request: ConnectionRequest
    ): Connection {
        Log.d("MyConnectionService", "📤 Outgoing call initiated")
        val connection = MyConnection()
        connection.setConnectionProperties(Connection.PROPERTY_SELF_MANAGED)
        connection.setAddress(request.address, TelecomManager.PRESENTATION_ALLOWED)
        connection.setDialing()
        return connection
    }
}

class MyConnection : Connection() {
    override fun onAnswer() {
        Log.d("MyConnection", "✅ Call answered")
        setActive()
    }

    override fun onReject() {
        Log.d("MyConnection", "❌ Call rejected")
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        destroy()
    }

    override fun onDisconnect() {
        Log.d("MyConnection", "🔴 Call disconnected")
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }
}
