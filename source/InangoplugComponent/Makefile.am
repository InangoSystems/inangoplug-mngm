##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2017 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

##########################################################################
#
# Includes Inango Systems Ltd's changes/modifications dated: 2021.
# Changed/modified portions - Copyright (c) 2021, Inango Systems Ltd.
#
##########################################################################

bin_PROGRAMS = inangoplug_component

AM_CPPFLAGS = -I$(top_srcdir)/hal/include \
		-I$(top_srcdir)/source/InangoplugComponent \
		-I=${includedir} \
		-I=${includedir}/ccsp \
		-I=${includedir}/tirpc

inangoplug_component_SOURCES = cosa_apis_inangoplugcomponentplugin.c plugin_main.c ssp_action.c ssp_messagebus_interface.c ssp_main.c inangoplug_log.c
inangoplug_component_CFLAGS = -D_ANSC_LINUX -D_ANSC_USER -D_ANSC_LITTLE_ENDIAN_ $(DBUS_CFLAGS) -DFEATURE_SUPPORT_RDKLOG
inangoplug_component_LDFLAGS = -lccsp_common $(DBUS_LIBS) -lrdkloggers -llog4c -lpthread -ltirpc -lgwapiproxy
