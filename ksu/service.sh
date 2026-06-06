#!/system/bin/sh
GP="com.google.android.gms/com.google.android.gms.tapandpay.hce.service.TpHceService"
XM="com.android.nfc/com.android.nfc.cardemulation.ESEWalletDummyService"
touch /data/local/tmp/nfc_signal
chmod 666 /data/local/tmp/nfc_signal
LAST=""
while true; do
  CMD=$(cat /data/local/tmp/nfc_signal 2>/dev/null)
  [ "$CMD" != "$LAST" ] && { LAST="$CMD"; [ "$CMD" = "G" ] && settings put secure nfc_payment_default_component "$GP"; [ "$CMD" = "X" ] && settings put secure nfc_payment_default_component "$XM"; }
  sleep 0.1
done
