if [ -d /system/priv-app ]; then SOURCE=priv_app; else SOURCE=system_app; fi

if [ "$SEINJECT" != "/sbin/sepolicy-inject" ]; then
  $SEINJECT --live "allow $SOURCE property_socket sock_file { getattr open read write execute }" "allow $SOURCE init unix_stream_socket connectto" "permissive $SOURCE audio_prop"
else
  $SEINJECT -s $SOURCE -t init -c unix_stream_socket -p connectto -l
  $SEINJECT -s $SOURCE -t property_socket -c sock_file -p getattr,open,read,write,execute -l
  $SEINJECT -Z $SOURCE -l
  $SEINJECT -Z audio_prop -l
fi
