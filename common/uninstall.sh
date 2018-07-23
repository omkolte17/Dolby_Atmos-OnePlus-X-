if ! $MAGISK || $SYSOVERRIDE; then
  for OFILE in ${CFGS}; do
    FILE="$UNITY$(echo $OFILE | sed "s|^/vendor|/system/vendor|g")"
    case $FILE in
      *.conf) [ "$DOLBY" == "axon7" ] && sed -i "/proxy { #$MODID/,/} #$MODID/d" $FILE
              sed -i '/dax { #$MODID/,/} #$MODID/d' $FILE
              sed -i '/dax_sw { #$MODID/,/} #$MODID/d' $FILE
              sed -i '/dax_hw { #$MODID/,/} #$MODID/d' $FILE;;
      *.xml) [ "$DOLBY" == "axon7" ] && sed -i "/<effectProxy name=\"proxy\" library=\"proxy\" uuid=\"9d4921da-8225-4f29-aefa-6e6f69726861\"><!--$MODID-->/,/<\/effectProxy><!--$MODID-->/d" $FILE
             sed -i '/<!--$MODID-->/d' $FILE;;
    esac
  done
fi
