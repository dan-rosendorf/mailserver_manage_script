#!/bin/perl

# This script manages user accounts and aliases for a mail server database.
# It provides functionality to add users, remove users, change passwords, and add aliases.
#
# Functionality:
# - Adds a new user to the mail server database.
# - Removes an existing user from the mail server database.
# - Changes the password for an existing user.
# - Adds an alias for email forwarding.
#
# Required Parameters:
# -name <username>    : The username to be added, removed, or whose password is to be changed.
# -password <password>: The password for the new user or to update an existing user's password (only for add-user and change-password).
# -source <email>     : The source email address for the alias (only for add-alias).
# -destination <email>: The destination email address for the alias (only for add-alias).
#
# Optional Parameters:
# -host <hostname>    : The hostname of the database server (default: localhost).
# -database <database>: The name of the database (default: mailserver).
# -domain <domain>    : The domain of the email address (default: marinco.cz).
#
# Dependencies:
# - Requires the DBI module for database interaction.
# - Requires the Getopt::Long module for command-line argument parsing.
#
# Usage:
# perl mailmanage.pl <command> [options]
#
# Commands:
# - add-user        : Adds a new user to the database.
# - remove-user     : Removes an existing user from the database.
# - change-password : Changes the password for an existing user.
# - add-alias       : Adds an alias for email forwarding.
#
# Examples:
# perl mailmanage.pl add-user -name user1 -password pass123 -host localhost -database mailserver -domain marinco.cz
# perl mailmanage.pl remove-user -name user1 -host localhost -database mailserver -domain marinco.cz
# perl mailmanage.pl change-password -name user1 -password newpass -host localhost -database mailserver -domain marinco.cz
# perl mailmanage.pl add-alias -source alias@domain.com -destination user@domain.com -host localhost -database mailserver -domain marinco.cz

use strict;
use warnings;
use DBI;
use Getopt::Long;
use Pod::Usage;

# Get command from first argument
my $command = shift @ARGV || 'help';

# Define available commands
my %commands = (
    'add-user'        => \&add_user,
    'remove-user'     => \&remove_user,
    'change-password' => \&change_password,
    'add-alias'       => \&add_alias,
    'help'            => \&show_help,
);

# Read options
my $database = 'mailserver';
my $host = 'localhost';
my $port = '3306';
my $domain = 'marinco.cz';
my $dbh;
my $passwd;
my $username;
my $alias;
my $source;
my $destination;

GetOptions(
	"host=s"     => \$host,     # host name
	"database=s" => \$database, # database name
	"domain=s"   => \$domain,   # mail domain
	"name=s"     => \$username, # username
	"password=s" => \$passwd,    # password
	"alias=s"   => \$alias,   # alias
	"port=i"     => \$port,     # port number
	"source=s"   => \$source,   # source
	"destination=s" => \$destination, # destination
	"help"       => sub { pod2usage(1) }, # help message
) or pod2usage(2);

# Validate command existence
if (!exists $commands{$command}) {
    print "Unknown command: $command\n";
    show_help();
    exit(1);
}

# Connect to the database
$dbh=connect_db($host,$database,$port);



# Validate parameters
validate_params($command);

# Execute the command
$commands{$command}->();

# Disconnect from the database
$dbh->disconnect();

exit(0);


sub add_user {
    my $newid = getMaxUserId() + 1;

    if ($username =~ /\@/) {
        my ($user,$domain)=split($username, '@');
        
    }

	# Get domain IDs
	my $domain_id = getDomainId($domain);
	if (!$domain_id) {
		print "Couldn't find domain $domain\n";
		die(0);
	}

    my $adduserh = $dbh->prepare(
        "INSERT INTO virtual_users (id, domain_id, password, email) VALUES (?, ?, ENCRYPT(?, CONCAT('\$6\$', SUBSTRING(SHA(RAND()), -16))), ?)"
    );
    $adduserh->execute($newid, $domain_id, $passwd, "$username\@$domain");
    print "User $username\@$domain added successfully\n";
}

sub remove_user {
    my $email = "$username\@$domain";
    my $sth = $dbh->prepare("DELETE FROM virtual_users WHERE email = ?");
    my $rows = $sth->execute($email);
    
    if ($rows == 0) {
        print "User $email not found\n";
    } else {
        print "User $email removed successfully\n";
    }
}

sub change_password {
	my $email = "$username\@$domain";
	my $sth = $dbh->prepare("UPDATE virtual_users SET password = ENCRYPT(?, CONCAT('\$6\$', SUBSTRING(SHA(RAND()), -16))) WHERE email = ?");
	my $rows = $sth->execute($passwd, $email);
	
	if ($rows == 0) {
		print "User $email not found\n";
	} else {
		print "Password for user $email changed successfully\n";
	}
}

sub add_alias {
    # Get domain IDs
    my ($source_user, $source_domain) = split('@', $source);
    $source_domain ||= $domain;


	my $domain_id = getDomainId($source_domain);
	if(!$domain_id){
		print "Couldn't find domain $source_domain\n";
		die(0);
	}
	

	my $newid = getMaxIdFromTable("virtual_aliases")+1;
    
    my $sth = $dbh->prepare(
        "INSERT INTO virtual_aliases (id, domain_id, source, destination) VALUES (?, ?, ?, ?)"
    );
    
    $sth->execute($newid,$domain_id, $source, $destination);
    print "Alias from $source to $destination added successfully\n";
}

sub getDomainId {
	my $curdomain = $_[0];

	if (!$curdomain) {
		print "No domain provided\n";
		die(0);
	}

	my $domh = $dbh->prepare("SELECT * FROM virtual_domains WHERE name = ?");
	
	$domh->execute($curdomain);
	
	if (!$domh->execute()) {
		print "Couldn't find virtual domain $curdomain\n";
		die(0);
	}
	my $ref = $domh->fetchrow_hashref();
	return ($ref->{'id'});
}


# This subroutine retrieves the maximum ID from a specified table in the database.
#
# Parameters:
#   - $table: The name of the table from which to retrieve the maximum ID.
#
# Returns:
#   - The maximum ID from the specified table, or -1 if the table name is not provided.
#
# Behavior:
#   - If the table name is not provided, the subroutine returns -1.
#   - It prepares and executes a SQL query to select the maximum ID from the specified table.
#   - If the query execution fails or no result is found, it prints an error message and terminates the script.
#   - If a result is found, it returns the maximum ID.
#
# Errors:
#   - Prints an error message and terminates the script if the table name is not provided or if the query fails.
#   - The error message includes the table name for easier debugging.
#
sub getMaxIdFromTable {
	my $table = $_[0];
	if (!$table) {
		return (-1);
	}

	my $query = "SELECT MAX(id) AS max_id FROM $table";
	my $maxsth = $dbh->prepare($query);
	$maxsth->execute();
	my $ref = $maxsth->fetchrow_hashref();
	if (!$ref) {
		print "Couldn't find max id in table $table\n";
		die(0);
	}
	my $maxid = $ref->{'max_id'};
	return $maxid;
}

sub getMaxUserId {
	return (getMaxIdFromTable("virtual_users"));
}


# This subroutine establishes a connection to the database.
# It is responsible for initializing and returning a database handle (DBI object).
# Ensure that the necessary database configuration (e.g., DSN, username, password)
# is properly set before calling this subroutine.
# 
# Parameters:
#   - $host: The hostname of the database server.
#   - $database: The name of the database to connect to.
#   - $port: (Optional) The port number for the database connection.
# 
# Returns:
#   A database handle (DBI object) on successful connection.
# 
# Throws:
#   An exception if the connection to the database fails.
sub connect_db {
    my ($host, $database, $port) = @_;
    my $dsn = "DBI:MariaDB:host=$host;database=$database";
    if($host ne 'localhost' && $port) {
        $dsn .= ";port=$port";
    }

    
    
    my $dbh = DBI->connect($dsn, 'root', undef, {RaiseError => 0, PrintError => 1});
    
    if (!$dbh) {
        die "Couldn't connect to database: $DBI::errstr\n";
    }
    return $dbh;
}



# This subroutine validates the parameters required for various mail management commands.
# 
# Parameters:
#   - $cmd: A string representing the command to be executed. Supported commands are:
#       * 'add-user': Requires -name <username> and -password <password>.
#       * 'change-password': Requires -name <username> and -password <password>.
#       * 'remove-user': Requires -name <username>.
#       * 'add-alias': Requires -source <email> and -destination <email>.
#
# Behavior:
#   - For each command, the subroutine checks if the required parameters are provided.
#   - If a required parameter is missing, the subroutine terminates execution with an error message.
#
# Errors:
#   - "-name <username> is required" if the username is missing for 'add-user', 'change-password', or 'remove-user'.
#   - "-password <password> is required" if the password is missing for 'add-user' or 'change-password'.
#   - "-source <email> is required" if the source email is missing for 'add-alias'.
#   - "-destination <email> is required" if the destination email is missing for 'add-alias'.
sub validate_params {
    my $cmd = shift;
    
    if ($cmd eq 'add-user' || $cmd eq 'change-password') {
        die "-name <username> is required\n" unless $username;
        die "-name <username> must not contain more than one '@'\n" if ($username =~ tr/@// > 1);
        die "-password <password> is required\n" unless $passwd;
    } 
    elsif ($cmd eq 'remove-user') {
        die "-name <username> is required\n" unless $username;
    } 
    elsif ($cmd eq 'add-alias') {
        die "-source <email> is required\n" unless $source;
        die "-destination <email> is required\n" unless $destination;
    }
}

sub show_help {
    print <<'EOH';
Usage: perl mailadduser.pl <command> [options]

Commands:
  add-user        - Add a new mail user
  remove-user     - Remove an existing mail user
  change-password - Change a user's password
  add-alias       - Add a mail alias
  help            - Show this help message

Common Options:
  -host <hostname>     - Database hostname (default: localhost)
  -database <database> - Database name (default: mailserver)
  -domain <domain>     - Mail domain (default: marinco.cz)

Command-specific Options:
  add-user, change-password, remove-user:
    -name <username>     - Username
    -password <password> - Password (only for add-user, change-password)
    
  add-alias:
    -source <email>      - Source email address
    -destination <email> - Destination email address

Examples:
  perl mailadduser.pl add-user -name user1 -password pass123
  perl mailadduser.pl remove-user -name user1
  perl mailadduser.pl change-password -name user1 -password newpass
  perl mailadduser.pl add-alias -source alias@domain.com -destination user@domain.com
EOH
}

__END__

=head1 NAME

mailadduser.pl - Mail server user management utility

=head1 SYNOPSIS

mailadduser.pl <command> [options]

=head1 DESCRIPTION

This script provides commands to manage users and aliases in a mail server database.