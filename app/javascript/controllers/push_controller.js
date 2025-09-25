import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "button"]
  static values = { subscribed: Boolean }

  connect() {
    this.updateStatus()
  }

  async enable() {
    try {
      if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
        this.flash('Push not supported on this browser')
        return
      }
      const perm = await Notification.requestPermission()
      if (perm !== 'granted') { this.flash('Notifications permission denied'); return }

      const reg = await navigator.serviceWorker.ready
      const key = (window.VAPID_PUBLIC_KEY || "").trim()
      const applicationServerKey = this.urlBase64ToUint8Array(key)
      const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey })

      const res = await fetch('/push_subscriptions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.csrf() },
        body: JSON.stringify({ subscription: sub.toJSON(), platform: navigator.platform })
      })
      if (!res.ok) throw new Error('Subscribe failed')
      this.subscribedValue = true
      this.updateStatus()
    } catch (e) {
      this.flash(`Unable to enable push: ${e.message}`)
    }
  }

  async disable() {
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      if (sub) { await sub.unsubscribe() }
      // Best effort server-side cleanup: unfurl id from endpoint
      this.subscribedValue = false
      this.updateStatus()
    } catch (e) {
      this.flash(`Unable to disable push: ${e.message}`)
    }
  }

  updateStatus() {
    if (this.hasStatusTarget) this.statusTarget.textContent = this.subscribedValue ? 'Enabled' : 'Disabled'
    if (this.hasButtonTarget) this.buttonTarget.textContent = this.subscribedValue ? 'Disable' : 'Enable'
  }

  csrf() { return document.querySelector('meta[name="csrf-token"]').getAttribute('content') }

  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) { outputArray[i] = rawData.charCodeAt(i); }
    return outputArray;
  }

  flash(msg) {
    console.warn(msg)
  }
}

