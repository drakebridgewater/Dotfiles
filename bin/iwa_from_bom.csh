#!/bin/sh

#set iwaPath=${HOME}/iwa
#set iwaPath=/wv/djohnsen/iwa

set iwaPath=`pwd`
set buildConfiguration=`readlink /wv/icdet/work_areas/latest_ube`
mkdir -p  $iwaPath/$buildConfiguration

cd $iwaPath/$buildConfiguration

#/home/icdet/bin/build_iwa_from_bom -src /wv/click_build/BLESSED/bom.tgz aoi
/home/icdet/bin/build_iwa_from_bom -src /wv/icdet/work_areas/latest_ube/.bom/bom.tgz aoi
cd ic
foreach d ( ic_superproj lv )
    cd $d;
    mkwa  . . \
    aaw \
    cd -
end


