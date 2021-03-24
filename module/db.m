DB : module
{
	PATH : con "/dis/lib/db.dis";

	# Open the connection to the DB server
    	# returns (New handle, "") or (nil, "Error Message")
  	open:		fn(addr: string, username: string, 
			   password: string, dbname: string) : (ref DB_Handle, list of string);


	DB_Handle : adt
	{
	        # Execute the SQL command
		# returns (0, "") or (error code, "Message")
	    	SQL:	fn(handle: self ref DB_Handle, command: string): (int, list of string);

		# Check the number of columns of last select command
		columns:	fn(handle: self ref DB_Handle): int;

		# Fetch the next row of the selection results.
		# returns current row number, or 0
	  	nextRow:	fn(handle: self ref DB_Handle): int;	

		# Read the data of column[i] of current row
	  	read:	fn(handle: self ref DB_Handle, column: int): (int, array of byte);

		# Title of the column[i]
	  	columnTitle: 	fn(handle: self ref DB_Handle, column: int): string;

		# Close DB
		# returns (0, "") or (-1, "Error Message")
	  	close:		fn(handle: self ref DB_Handle): (int, list of string);

	
		#error message associated with last command
		errmsg:		fn(handle: self ref DB_Handle): string;

		conn: ref Sys->Connection;

	};
};
