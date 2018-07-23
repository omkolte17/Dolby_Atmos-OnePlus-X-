osp_detect() {
  case $1 in
    *.conf) SPACES=$(sed -n "/^output_session_processing {/,/^}/ {/^ *music {/p}" $1 | sed -r "s/( *).*/\1/")
            EFFECTS=$(sed -n "/^output_session_processing {/,/^}/ {/^$SPACES\music {/,/^$SPACES}/p}" $1 | grep -E "^$SPACES +[A-Za-z]+" | sed -r "s/( *.*) .*/\1/g")
            for EFFECT in ${EFFECTS}; do
              SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$EFFECT {/p}" $1 | sed -r "s/( *).*/\1/")
              [ "$EFFECT" != "atmos" ] && sed -i "/^effects {/,/^}/ {/^$SPACES$EFFECT {/,/^$SPACES}/ s/^/#/g}" $1
            done;;
     *.xml) EFFECTS=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"music\">$/,/^ *<\/stream>$/ {/<stream type=\"music\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; p}}" $1)
            for EFFECT in ${EFFECTS}; do
              [ "$EFFECT" != "atmos" ] && sed -ri "s/^( *)<apply effect=\"$EFFECT\"\/>/\1<\!--<apply effect=\"$EFFECT\"\/>-->/" $1
            done;;
  esac
}

# Tell user aml is needed if applicable
if $MAGISK && ! $SYSOVERRIDE; then
  if $BOOTMODE; then LOC="/sbin/.core/img/*/system $MOUNTPATH/*/system"; else LOC="$MOUNTPATH/*/system"; fi
  FILES=$(find $LOC -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" 2>/dev/null)
  if [ ! -z "$FILES" ] && [ ! "$(echo $FILES | grep '/aml/')" ]; then
    ui_print " "
    ui_print "   ! Conflicting audio mod found!"
    ui_print "   ! You will need to install !"
    ui_print "   ! Audio Modification Library !"
    sleep 3
  fi
fi

rm -rf /data/app/com.atmos*

# Choose between new and old ui if dolby port supports it
if [ "$DOLBY" != "AxAxon7" ] && [ "$DOLBY" != "AxA7000-6.5" ]; then
  OLD=false; NEW=false;
  # GET OLD/NEW FROM ZIP NAME
  case $(basename $ZIP) in
    *old*|*Old*|*OLD*) OLD=true;;
    *new*|*New*|*NEW*) NEW=true;;
  esac

  # Keycheck binary by someone755 @Github, idea for code below by Zappo @xda-developers
  chmod 755 $INSTALLER/common/keycheck

  keytest() {
    ui_print "- Vol Key Test -"
    ui_print "   Press Vol Up:"
    (/system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events) || return 1
    return 0
  }

  chooseport() {
    #note from chainfire @xda-developers: getevent behaves weird when piped, and busybox grep likes that even less than toolbox/toybox grep
    while (true); do
      /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events
      if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUME >/dev/null`); then
        break
      fi
    done
    if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUMEUP >/dev/null`); then
      return 0
    else
      return 1
    fi
  }

  chooseportold() {
    # Calling it first time detects previous input. Calling it second time will do what we want
    $INSTALLER/common/keycheck
    $INSTALLER/common/keycheck
    SEL=$?
    if [ "$1" == "UP" ]; then
      UP=$SEL
    elif [ "$1" == "DOWN" ]; then
      DOWN=$SEL
    elif [ $SEL -eq $UP ]; then
      return 0
    elif [ $SEL -eq $DOWN ]; then
      return 1
    else
      ui_print "   Vol key not detected!"
      abort "   Use name change method in TWRP"
    fi
  }

  if ! $NEW && ! $OLD; then
    ui_print " "
    if keytest; then
      FUNCTION=chooseport
    else
      FUNCTION=chooseportold
      ui_print "   ! Legacy device detected! Using old keycheck method"
      ui_print " "
      ui_print "- Vol Key Programming -"
      ui_print "   Press Vol Up Again:"
      $FUNCTION "UP"
      ui_print "   Press Vol Down"
      $FUNCTION "DOWN"
    fi
    ui_print " "
    ui_print "- Select Version -"
    ui_print "   Choose which dolby ui you want installed:"
    ui_print "   Vol+ = new, Vol- = old"
    if $FUNCTION; then
      NEW=true
    else
      OLD=true
    fi
  else
    ui_print  "   Dolby ui version specified in zipname!"
  fi

  if $NEW; then
    ui_print "   New ui will be installed"
    cp -f $INSTALLER/custom/AxUI.apk $INSTALLER/system/app/AxUI/AxUI.apk
  else
    ui_print "  Old ui will be installed"
  fi
fi

ui_print "   Patching existing audio_effects files..."
if [ "$DOLBY" == "AxAxon7" ]; then
  for OFILE in ${CFGS}; do
    FILE="$UNITY$(echo $OFILE | sed "s|^/vendor|/system/vendor|g")"
    cp_ch_nb $ORIGDIR$OFILE $FILE 0644 false
    osp_detect $FILE
    case $FILE in
      *.conf) if [ ! "$(grep "dax" $FILE)" ]; then
                if [ ! "$(grep '^ *proxy {' $FILE)" ]; then
                  sed -i "s/^libraries {/libraries {\n  proxy { #$MODID\n    path $LIBPATCH\/lib\/soundfx\/libeffectproxy.so\n  } #$MODID/g" $FILE
                fi
                sed -i "s/^effects {/effects {\n  dax { #$MODID\n    library proxy\n    uuid 9d4921da-8225-4f29-aefa-6e6f69726861\n\n    libsw {\n      library dax_sw\n      uuid 6ab06da4-c516-4611-8166-6168726e6f69\n    }\n\n    libhw {\n      library dax_hw\n      uuid a0c30891-8246-4aef-b8ad-696f6e726861\n    }\n  } #$MODID/g" $FILE
                sed -i "s/^libraries {/libraries {\n  dax_hw { #$MODID\n    path $LIBPATCH\/lib\/soundfx\/libhwdax.so\n  } #$MODID/g" $FILE
                sed -i "s/^libraries {/libraries {\n  dax_sw { #$MODID\n    path $LIBPATCH\/lib\/soundfx\/libswdax.so\n  } #$MODID/g" $FILE
              fi;;
      *.xml) if [ ! "$(grep "dax" $FILE)" ]; then
               if [ ! "$(grep "<library name=\"proxy\" path=\"libeffectproxy.so\"\/>" $FILE)" ]; then
                 sed -i "/<libraries>/ a\        <library name=\"proxy\" path=\"libeffectproxy.so\"\/><!--$MODID-->" $FILE
               fi
               sed -i "/<libraries>/ a\        <library name=\"dax_hw\" path=\"libhwdax.so\"\/><!--$MODID-->" $FILE
               sed -i "/<libraries>/ a\        <library name=\"dax_sw\" path=\"libswdax.so\"\/><!--$MODID-->" $FILE
               sed -i -e "/<effects>/ a\        <effectProxy name=\"proxy\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\"><!--$MODID-->" -e "/<effects>/ a\            <libsw library=\"dax_sw\" uuid=\"6ab06da4-c516-4611-8166-6168726e6f69\"\/>" -e "/<effects>/ a\            <libhw library=\"dax_hw\" uuid=\"a0c30891-8246-4aef-b8ad-696f6e726861\"\/>" -e "/<effects>/ a\        <\/effectProxy><!--$MODID-->" $FILE
             fi;;
    esac
  done
else
  for OFILE in ${CFGS}; do
    FILE="$UNITY$(echo $OFILE | sed "s|^/vendor|/system/vendor|g")"
    cp_ch_nb $ORIGDIR$OFILE $FILE 0644 false
    osp_detect $FILE
    case $FILE in
      *.conf) sed -i "s/^effects {/effects {\n  dax { #$MODID\n    library dax\n    uuid 9d4921da-8225-4f29-aefa-6e6f69726861\n  } #$MODID/g" $FILE
              sed -i "s/^libraries {/libraries {\n  dax { #$MODID\n    path $LIBPATCH\/lib\/soundfx\/libswdax.so\n  } #$MODID/g" $FILE;;
      *.xml) sed -i "/<libraries>/ a\        <library name=\"dax\" path=\"libswdax.so\"\/><!--$MODID-->" $FILE
             sed -i "/<effects>/ a\        <effect name=\"dax\" library=\"dax\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\"\/><!--$MODID-->" $FILE;;
    esac
  done
fi
