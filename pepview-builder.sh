#!/bin/bash

main() {
	prep_pep_definitions \
		| tee >(mk_pepview > pepview.re) >(mk_pepview_default_peps > pepview-default-peps.re) \
		> /dev/null
}


prep_pep_definitions() {
	curl --silent https://docs.irods.org/4.2.8/plugins/dynamic_policy_enforcement_points/ \
		| sed --quiet 's|<tr><td>\(pep_[^<]*\)</td><td>\(.*\)</td></tr>|\1\t\2|p' \
		| grep --invert PLUGINOPERATION \
		| sed 's|<br/>|\t|g' \
		| sed 's|</\?strong>||g' \
		| sed 's/&amp;/\&/g' \
		| tr --squeeze ' ' \
		| sort
}


mk_pepview() {
	write_pepview_header
	mk_rules WITH_LOGIC
}


mk_pepview_default_peps() {
	write_pepview_defaults_header
	mk_rules EMPTY
}


write_pepview_header() {
	cat <<'EOF'
# pepview
#
# pepview aids someone trying to gain insight into which dynamic PEPs are
# triggered and in what order when an action is taken within the iRODS zone. It
# also provides insight into what information is passed into rules attached to
# these PEPs. It does this by writing to the rodsLog. In its most verbose
# configuration, each of its rules will log the calling PEP signature and all
# arguments passed to it. The logging can be restricted to certain PEPs and
# argument value logging can be enabled or disabled. It can also be configured
# to not interfere with the execution of existing policies.
#
# pepview provides an implementation for every dynamic PEP in stock iRODS 4.2.8.
# See https://docs.irods.org/4.2.8/plugins/dynamic_policy_enforcement_points/
# for exactly which ones.
#
# For pepview to function properly, it must be setup as its own iRODS rule
# language rule engine plugin instance with this file being the only rule base,
# and all of the servers in the grid should be configured so that this engine
# instance is called before any others. The pepview engine instance should have
# no RE data variable or function name mappings. If servers are configured with
# more the one iRODS rule language engine instance, make sure that the two
# instances  have different names and different shared memory instances.
#
# Here's an exmple entry for the plugin_configuration.rule_engines array in
# server_config.json.
#
#   {
#     "instance_name": "pepview-instance",
#     "plugin_name": "irods_rule_engine_plugin-irods_rule_language",
#     "plugin_specific_configuration": {
#       "re_data_variable_mapping_set": [],
#       "re_function_name_mapping_set": [],
#       "re_rulebase_set": [
#         "pepview"
#       ],
#       "regexes_for_supported_peps": [
#         "ac[^ ]*",
#         "msi[^ ]*",
#         "[^ ]*pep_[^ ]*_(pre|post|except|finally)"
#       ]
#     },
#     "shared_memory_instance": "pepview_rule_engine"
#   }


# CONFIGURABLE PARAMETERS
#
# The following parameters can be modified to control the behavior of the
# pepview policies.

# This parameter controls whether or not the pepview rules to send a
# continuation to the rule engine after writing out their call details. This
# will keep pepview from interfering with the normal policies.

pepview_CONTINUE = false


# This parameter controls which plugins pepview will log call details about. It
# accepts a list of plugin names. The supported plugins are 'api', 'auth',
# 'database', 'microservices', 'network', and 'resource'. The parameter can be
# assigned to the constant pepview_ALL_PLUGINS to have pepview log the call
# details for all supported plugins.

pepview_PLUGINS_SHOWN = list()
#pepview_PLUGINS_SHOWN = pepview_ALL_PLUGINS


# This parameter controls which plugin operations pepview will log call details
# about. It accepts a list of operation name wildcard patterns. The operation
# name for a dynamic PEP is derived from the PEP's name. A PEP name is a
# sequence of words separated by underscores. The first word is always "pep".
# The second is the name of the plugin invoking the PEP, and the last is the
# stage of the operation. The remaining words between the second and last form
# operation name. For example, if the name of the PEP is
# "pep_PLUGIN_doing_something_STAGE", the operation name is "doing_something".
# The parameter can be assigned to the constant pepview_ALL_OPS to have pepview
# display call details for all operations.

#pepview_OPS_SHOWN = list()
pepview_OPS_SHOWN = pepview_ALL_OPS


# This parameter controls which operation stages or phases pepview will log call
# details about. It accepts a list of stages. The stages are 'pre', 'post',
# 'except', and 'finally'. The parameter can be assigned to the constant
# pepview_ALL_STAGES to have pepview display call details for all stages.

#pepview_STAGES_SHOWN = list()
pepview_STAGES_SHOWN = pepview_ALL_STAGES


# This parameter controls how the PEP rule arguments are displayed. A value of
# 'compact' means that the arguments will be displayed one per line. The ones
# with structured values will have all fields displayed on that line with fields
# separated by '++++'.  A value of 'expanded' is similar to 'compact', except
# that the fields of structured values will also be diplsayed one per line. A
# value of 'none' (or any other value) means the argument values will not be
# displayed.

pepview_ARGS_DISPLAY = 'none'


# CONFIGURATION CONSTANTS
#
# No need to modify them

pepview_ALL_PLUGINS = list('api', 'auth', 'database', 'microservices', 'network', 'resource')
pepview_ALL_OPS = list('all')
pepview_ALL_STAGES = list('pre', 'post', 'except', 'finally')


# FUNCTIONS SUPPORTING PEP IMPLEMENTATIONS
#
# No need to modify them

_pepview_contains(*List, *Elem) =
	if size(*List) == 0 then false
	else if *Elem == hd(*List) then true
	else _pepview_contains(tl(*List), *Elem)

_pepview_contains_similar(*List, *Elem) =
	if size(*List) == 0 then false
	else if *Elem like hd(*List) then true
	else _pepview_contains(tl(*List), *Elem)

_pepview_showOp(*OpPat) =
	if _pepview_contains(pepview_OPS_SHOWN, 'all') then true
	else _pepview_contains_similar(pepview_OPS_SHOWN, *OpPat)

_pepview_showPlugin(*Plugin) = _pepview_contains(pepview_PLUGINS_SHOWN, *Plugin)

_pepview_showStage(*Stage) = _pepview_contains(pepview_STAGES_SHOWN, *Stage)

_pepview_showPep(*Plugin, *OpPat, *Stage) =
	if ! _pepview_showPlugin(*Plugin) then false
	else if ! _pepview_showOp(*OpPat) then false
	else _pepview_showStage(*Stage)

_pepview_writeArg(*Name, *Val) {
	if (pepview_ARGS_DISPLAY == 'compact') {
		writeLine('serverLog', '*Name = *Val');
	} else if (pepview_ARGS_DISPLAY == 'expanded') {
		if (str(*Val) like '*++++*') {
			foreach (*kv in *Val) {
				writeLine('serverLog', '*Name.*kv = ' ++ *Val.'*kv');
			}
		} else {
			writeLine('serverLog', '*Name = *Val');
		}
	}
}

_pepview_exit {
	if (pepview_CONTINUE) {
		5000000;
	}
}


# DYNAMIC PEP IMPLEMENTATIONS
#
# No need to modify them
EOF
}


write_pepview_defaults_header() {
	cat << 'EOF'
# pepview-default-peps
#
# This rule base provides NO-OP implentations for all dynamic PEPs supported by
# pepview.
#
# For pepview to function properly, this file must be added as the last rule
# base before the core rule base for the iRODS rule language rule engine.
#
# See the pepview rule base for more information about pepview.


# NO-OP DYNAMIC PEP IMPLEMENTATIONS
#
# No need to modify them
EOF
}


mk_rules() {
	local content="$1"

	awk --assign CONTENT="$content" --file - <(cat) <<'EOAWK'
function translate_name(arg) {
	numTerms = split(arg, terms, " ", seps);
	sub(/^_/, "", terms[numTerms]);
	return toupper(terms[numTerms]);
}

function translate_arg(arg, pos) {
	switch (arg) {
		case /irods::plugin_context/:       return "CONTEXT";
		case /rsComm_t|int \* rsComm/:      return "COMM";
		case /^rodsEnv /:                   return "RODSENV" pos;
		case /int \* $/:                    return "_INT" pos;
    case /char \* $|std::string \* $/:  return "_STR" pos;
		default:                            return translate_name(arg);
	}
}


function determine_op(pep) {
	return gensub(/^pep_[^_]+_(.+)_[^_]+$/, "\\1", 1, pep);
}


function determine_plugin(pep) {
	return gensub(/^pep_([^_]+)_.*/, "\\1", 1, pep);
}


function determine_stage(pep) {
	return gensub(/.*_([^_]+)$/, "\\1", 1, pep);
}


function mk_text_rule_decl(name, args, argCnt) {
	text = name "(";

	for (i = 1; i <= argCnt; i++) {
		text = text args[i];

		if (i < argCnt) {
			text = text ", ";
		}
	}

	text = text ")";

	return text;
}


function mk_rule_decl(name, args, argCnt) {
	decl = name "(";

	for (i = 1; i <= argCnt; i++) {
		decl = decl "*" args[i];

		if (i < argCnt) {
			decl = decl ", ";
		}
	}

  decl = decl ")";

	return decl;
}


function mk_rule_body(name, args, argCnt) {
	plugin = determine_plugin(name);
	op = determine_op(name);
	stage = determine_stage(name);
  declSerial = mk_text_rule_decl(name, args, argCnt);

  body = "";
	body = body sprintf("{\n");

	if (CONTENT != "EMPTY") {
		body = body sprintf("\ton (_pepview_showPep('%s', '%s', '%s')) {\n", plugin, op, stage);
		body = body sprintf("\t\twriteLine('serverLog', '%s');\n", declSerial);

		for (i in args) {
			body = body sprintf("\t\teval(``_pepview_writeArg('%s', *%s)``);\n", args[i], args[i]);
		}

#		body = body sprintf("\t\t_pepview_exit;\n");
		body = body sprintf("\n");
		body = body sprintf("\t\tif (pepview_CONTINUE) {\n");
		body = body sprintf("\t\t\tfail;\n");
		body = body sprintf("\t\t}\n");
		body = body sprintf("\t}\n");
	}

	body = body sprintf("}");

	return body;
}


function mk_rule(name, args, argCnt) {
	return mk_rule_decl(name, args, argCnt) " " mk_rule_body(name, args, argCnt);
}


BEGIN {
	FS = "\t";
}


{
	pep = $1;

	argCnt = 0;
	args[++argCnt] = "INSTANCE";

	for (i = 2; i <= NF; i++) {
		args[++argCnt] = translate_arg($i, i);

		if (args[argCnt] == "CONTEXT") {
			args[++argCnt] = "OUT";
		}
	}

	printf "\n";
  printf "%s\n", mk_rule(pep, args, argCnt);
	delete args;
}
EOAWK
}


main "$@"
