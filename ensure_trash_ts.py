import os
from irods.meta import iRODSMeta
from irods.session import iRODSSession
from irods.models import Collection
from irods.meta import iRODSMeta
from irods.exception import CollectionDoesNotExist
import time
import sys

def add_trash_timestamp(sess: iRODSSession, trash_path: str) -> None:
	"""
	Iterate over /zone/trash; if it finds 'home' collection, go further down, iterate over user's trash folder,
	(e.g. /zone/trash/home/user) and add AVU to obj and collections under these.
	otherwise, for all non-home collections under /zone/trash like 'orphan', just add the AVU to it.
	"""
	print(f"Trash path - {trash_path}")
	try:
		coll_in_trash = sess.collections.get(trash_path)
	except CollectionDoesNotExist:
		print(f"CollectionDoesNotExist: Trash path is invalid - {trash_path}")
		return
	for coll_trash in coll_in_trash.subcollections: # inside zone/trash
		if coll_trash.name == "home":
			print(f"Examining collections and objects under 'home' - {coll_trash.path}")
			# iterate over user's trash collections, /zone/trash/home/user_collections
			# within user_collections, look for collections and objects to add avu
			for user_collections in coll_trash.subcollections:
				print(f"Examining collections and objects under {user_collections.path}")
				for coll in user_collections.subcollections:
					add_coll_avu(coll)
				for obj in user_collections.data_objects:
					add_obj_avu(obj)
		else:
		# if collection coll_trash is not home, like orphan, just add timestamp to it.
			print(f"Examining collections other than 'home' - {coll_trash.path}")
			add_coll_avu(coll_trash)
			

def add_coll_avu(col) -> None:
	"""
	Adds ipc::trash_timestamp to a collection if it doesn't exist
	"""
	print(f" Checking if AVU needs to be added to a collection - {col.path}")
	if "ipc::trash_timestamp" not in col.metadata.keys():
		epoch_time = time.time()  # prepend '0' to the epoch timestamp to follow irods convention
		trash_timestamp_meta = iRODSMeta('ipc::trash_timestamp', "0" + str(int(epoch_time))) 
		col.metadata[trash_timestamp_meta.name] = trash_timestamp_meta
		print(f"Added AVU to a collection - {col.path}")

def add_obj_avu(obj) -> None:
	"""
	Adds ipc::trash_timestamp to an object if it doesn't exist
	"""
	print(f" Checking if AVU needs to be added to a data obj - {obj.path}")
	if "ipc::trash_timestamp" not in obj.metadata.keys():
		epoch_time = time.time()  # prepend '0' to the epoch timestamp to follow irods convention
		trash_timestamp_meta = iRODSMeta('ipc::trash_timestamp', "0" + str(int(epoch_time)))
		obj.metadata[trash_timestamp_meta.name] = trash_timestamp_meta	
		print(f"Added ipc::trash_timestamp AVU to a data object - {obj.path}")

def main():
	"""
	Checks if IRODS_ENVIRONMENT_FILE is set, then use the IRODS account to create a session
	otherwise uses the default file at ~/.irods/irods_environment.json
	Calls the add_trash_timestamp method to iterate over items in the trash. 
	"""
	if 'IRODS_ENVIRONMENT_FILE' in os.environ:
		env = os.path.expanduser(os.environ.get('IRODS_ENVIRONMENT_FILE'))
	else:
		env = os.path.expanduser('~/.irods/irods_environment.json')
	if (len(sys.argv) >= 2):
		trash_path = f"/{sys.argv[1]}/trash" # takes zonename as cmd line arg
	else:
		print("Supply 'zone' argument, Usage: python3 add_timestamp_avu.py <zone_name>")
		return
	with iRODSSession(irods_env_file=env) as sess:
		add_trash_timestamp(sess, trash_path)
		print("Done!")

if __name__ == "__main__":
	main()
		
