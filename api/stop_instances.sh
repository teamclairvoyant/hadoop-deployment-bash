#!/bin/bash
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
#
# Copyright Clairvoyant 2016

REGION=us-west-2
CUSTOMER=unknown
PROFILE=

INSTANCES=`aws $PROFILE ec2 describe-instances --filter "Name=tag:customer,Values=${CUSTOMER}" --query 'Reservations[*].Instances[*].{ID:InstanceId}'`

for NODE in $INSTANCES; do
  aws $PROFILE ec2 stop-instances --instance-ids $NODE --region $REGION
done

