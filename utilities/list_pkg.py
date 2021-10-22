# Copyright 2014 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function

import sys, os

from catkin_tools.argument_parsing import add_context_args

from catkin_tools.context import Context

from catkin_tools.common import find_enclosing_package
from catkin_tools.common import get_recursive_build_dependents_in_workspace
from catkin_tools.common import get_recursive_build_depends_in_workspace
from catkin_tools.common import get_recursive_run_dependents_in_workspace
from catkin_tools.common import get_recursive_run_depends_in_workspace
from catkin_tools.common import getcwd

from catkin_pkg.packages import find_packages
from catkin_pkg.package import InvalidPackage
from catkin_pkg.topological_order import topological_order_packages

from catkin_tools.terminal_color import ColorMapper

import sys
import argparse

root = os.path.dirname(os.path.abspath(__file__))

parser = argparse.ArgumentParser(description='Output catkin packages in the workspacee')
parser.add_argument('output_type', metavar='TYPE', choices=('name', 'path'),
                    help='choose to output either package "name" or "path"')
parser.add_argument('--packages-select', metavar='PKG', nargs='+',
                    help='filter packages to be output. (by "package name")')
parser.add_argument('--src-folder', metavar='FOLDER', default='{}/src'.format(root),
                    help='set the src folder to be used for catkin tools')
parser.add_argument('--order', metavar='PKG', nargs='+',
                    help='when set, this ordered list will always be output before other packages (by "package name")')
parser.add_argument('--ignore', metavar='PKG', nargs='+',
                    help='a list of "packages name" to ignore')
parser.add_argument('--as-list', action='store_true',
                    help='make output as a cmake list (i.e. ; separated)')

args = parser.parse_args()

warnings = []

SRC = args.src_folder
folders = [SRC]

unformatted = True

outputs_buffer_name = []
outputs_buffer_path = []

ignores = set(args.ignore if args.ignore is not None else [])

def _print(zipped_item):
    idx = 0 if args.output_type == 'name' else 1
    print(zipped_item[idx])

for folder in folders:
    try:
        packages = find_packages(folder, warnings=warnings)
        ordered_packages = topological_order_packages(packages)
        packages_by_name = {pkg.name: (pth, pkg) for pth, pkg in ordered_packages}

        for pkg_pth, pkg in ordered_packages:
            if args.packages_select is not None:
                # filter by package name
                if pkg['name'] not in args.packages_select:
                    continue
            if pkg['name'] not in ignores:
                outputs_buffer_name.append(pkg['name'])
                outputs_buffer_path.append(os.path.join(SRC, pkg_pth))

    except InvalidPackage as ex:
        message = '\n'.join(ex.args)
        print("@{rf}Error:@| The directory %s contains an invalid package."
                    " See below for details:\n\n%s" % (folder, message))


# output everything as a semicolon separated list (for cmake)
# print(';'.join(outputs_buffer))

out = []
pkgs_order = args.order if args.order is not None else []

while len(pkgs_order):
    _desired_pkg = pkgs_order.pop(0)
    try:
        idx = outputs_buffer_name.index(_desired_pkg)
    except ValueError:
        # not exists
        continue
    # output this first
    _name = outputs_buffer_name.pop(idx)
    _path = outputs_buffer_path.pop(idx)
    if args.output_type == 'name':
        out.append(_name)
    else:
        out.append(_path)
        
# print the rest
for _name, _path in zip(outputs_buffer_name, outputs_buffer_path):
    if args.output_type == 'name':
        out.append(_name)
    else:
        out.append(_path)

if args.as_list:
    sys.stdout.write(';'.join(out))
else:
    print('\n'.join(out))
