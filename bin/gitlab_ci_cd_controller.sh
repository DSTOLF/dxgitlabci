#!/bin/bash
# Check if all necessary environment variables are set - if not, exit with error
[[ -z "$APP_PREFIX" \
  || -z "$DELPHIX_NAME" \
  || -z "$DELPHIX_ADDRESS" 
  || -z "$DELPHIX_USER" \
  || -z "$DELPHIX_PASSWORD" \
  || -z "$DELPHIX_TARGET_ENVIRONMENT" \
  || -z "$DELPHIX_DB_TYPE" \
  || -z "$DELPHIX_ENV_INST" \
  || -z "$DELPHIX_CONTAINER_OWNER" ]] && echo "Some necessary environment variables were not set" && exit 1

APP_PREFIX_UPPER=${APP_PREFIX^^}

# Set VDB Name - it must have at most 8 character, not start with numbers and not have "-"
TEMP=v${CI_COMMIT_REF_SLUG:0:6}
VDB_NAME=$(echo $TEMP | sed 's/-/_/g')

cp dxtools.conf.example dxtools.conf
sed -i "s/__DELPHIX_NAME__/${DELPHIX_NAME}/g" dxtools.conf
sed -i "s/__DELPHIX_ADDRESS__/${DELPHIX_ADDRESS}/g" dxtools.conf
sed -i "s/__DELPHIX_USER__/${DELPHIX_USER}/g" dxtools.conf
sed -i "s/__DELPHIX_PASSWORD__/${DELPHIX_PASSWORD}/g" dxtools.conf

# Test connection to Delphix
 dx_get_users > /dev/null

# If there isn't an Environment Variable with DELPHIX_DSOURCE, then get search Master from JetStream (SelfService) DataSources
# It's better set as an Environment Variable 
[ -z "$DELPHIX_DSOURCE" ] && DELPHIX_DSOURCE=$( dx_get_js_datasources -format csv | grep -v 'N/A' | grep $APP_PREFIX_UPPER | cut -d, -f4 | cut -d\/  -f2|awk '{$1=$1};1')
echo "Creating Environment from dSource: $DELPHIX_DSOURCE"



# Create a new VDB for the Git Branch
# The group "${APP_PREFIX_UPPER}-VDBS" must be previously created on Delphix admin page, or it will fail
if  ! ( dx_get_db_env -name $VDB_NAME -type vdb > /dev/null ); then 
  echo "Creating database $VDB_NAME"
   dx_provision_vdb -group "${APP_PREFIX_UPPER}-VDBS" -sourcename $DELPHIX_DSOURCE -targetname $VDB_NAME -dbname $VDB_NAME -environment "$DELPHIX_TARGET_ENVIRONMENT" -type $DELPHIX_DB_TYPE -envinst "$DELPHIX_ENV_INST"
else 
  echo "VDB Already exists"; 
fi

# Creates a new Container on SelfService, with the VDB we created earlier. 
# We'll also create a (Delphix container's) "branch", naming it after Gitlab's CI_COMMIT_REF_SLUG
if ! ( dx_get_js_containers -container_name $CI_COMMIT_REF_SLUG > /dev/null); then
  echo "Creating container $CI_COMMIT_REF_SLUG for VDB $VDB_NAME"
   dx_ctl_js_container -action create -container_name $CI_COMMIT_REF_SLUG -container_def ${APP_PREFIX_UPPER}-VDBS,${VDB_NAME} -container_owner ${DELPHIX_CONTAINER_OWNER} -template_name $APP_PREFIX_UPPER
  echo "Creating branch $CI_COMMIT_REF_SLUG"
   dx_ctl_js_branch -action create -container_name $CI_COMMIT_REF_SLUG -branch_name $CI_COMMIT_REF_SLUG
else
  echo "Container already exists."
   dx_ctl_js_container -action enable -container_name $CI_COMMIT_REF_SLUG || echo "Container is online"
fi

# Checks if previous commit has a bookmark - if it doesn't exist, then create it
if ! ( dx_get_js_bookmarks -template_name ${APP_PREFIX_UPPER} -container_name $CI_COMMIT_REF_SLUG -bookmark_name $CI_COMMIT_BEFORE_SHA > /dev/null); then
   dx_ctl_js_bookmarks -action create -container_name $CI_COMMIT_REF_SLUG -bookmark_name $CI_COMMIT_BEFORE_SHA -template_name ${APP_PREFIX_UPPER} -bookmark_time latest
else
  echo "Last commit already bookmarked"
fi

# Create a bookmark for current commit code
if ! ( dx_get_js_bookmarks -template_name ${APP_PREFIX_UPPER} -container_name $CI_COMMIT_REF_SLUG -bookmark_name $CI_COMMIT_SHA > /dev/null); then
   dx_ctl_js_bookmarks -action create -container_name $CI_COMMIT_REF_SLUG -bookmark_name $CI_COMMIT_SHA -template_name ${APP_PREFIX_UPPER} -bookmark_time latest
else
  echo "Current commit already bookmarked"
  if [[ "$CI_ROLLBACK" == "true" ]]; then 
	echo "CI_ROLLBACK environment variable is true, rolling back to bookmark $CI_COMMIT_SHA"
        dx_ctl_js_container -action restore -timestamp $CI_COMMIT_SHA -container_name $CI_COMMIT_REF_SLUG
  else 
	echo "CI_ROLLBACK environment variable is false, nothing to do."
  fi
fi

VDB_HOST=$( dx_get_db_env -name $VDB_NAME -type vdb -format csv | cut -d, -f2 | grep -v Hostname)

echo "Database provisioning finished:"
echo "Database: $VDB_NAME"
echo "Host: $VDB_HOST"
echo "SelfService Container / Branch: $CI_COMMIT_REF_SLUG"
echo "Latest bookmark: $CI_COMMIT_SHA"
