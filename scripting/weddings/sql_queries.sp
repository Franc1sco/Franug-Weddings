// SQL queries for the weddings_proposals table.

new String:sql_createProposals[] =
	"CREATE TABLE IF NOT EXISTS weddings_proposals (source_name VARCHAR(64), source_id VARCHAR(64) PRIMARY KEY, target_name VARCHAR(64), target_id VARCHAR(64));";

new String:sql_resetProposals[] = 
	"DELETE FROM weddings_proposals;";	
	
new String:sql_addProposal[] = 
	"INSERT INTO weddings_proposals VALUES ('%s', '%s', '%s', '%s');";
	
new String:sql_deleteProposalsSource[] =
	"DELETE FROM weddings_proposals WHERE source_id = '%s';";
	
new String:sql_deleteProposalsTarget[] = 
	"DELETE FROM weddings_proposals WHERE target_id = '%s';";
	
new String:sql_getProposals[] = 
	"SELECT source_name, source_id FROM weddings_proposals WHERE target_id = '%s';";
	
new String:sql_getAllProposals[] = 
	"SELECT * FROM weddings_proposals WHERE source_id ='%s' OR target_id = '%s';";
	
new String:sql_updateProposalSource[] = 
	"UPDATE weddings_proposals SET source_name = '%s' WHERE source_id = '%s';";
	
new String:sql_updateProposalTarget[] = 
	"UPDATE weddings_proposals SET target_name = '%s' WHERE target_id = '%s';";
	

// SQL queries for the weddings_marriages table.

new String:sql_createMarriages[] =
	"CREATE TABLE IF NOT EXISTS weddings_marriages (source_name VARCHAR(64), source_id VARCHAR(64) , target_name VARCHAR(64), target_id VARCHAR(64), score UNSIGNED INTEGER, timestamp UNSIGNED INTEGER);";
	
new String:sql_resetMarriages[] = 
	"DELETE FROM weddings_marriages;";
	
new String:sql_addMarriage[] = 
	"INSERT INTO weddings_marriages VALUES ('%s', '%s', '%s', '%s', %i, %i);";	
	
new String:sql_revokeMarriage[] = 
	"DELETE FROM weddings_marriages WHERE source_id ='%s' OR target_id = '%s';";	
	
new String:sql_getMarriage[] = 
	"SELECT * FROM weddings_marriages WHERE source_id = '%s' OR target_id = '%s';";	
	
new String:sql_getMarriages[] = 
	"SELECT * FROM weddings_marriages ORDER BY score DESC LIMIT %i;";	
	
new String:sql_updateMarriageSource[] = 
	"UPDATE weddings_marriages SET source_name = '%s' WHERE source_id = '%s';";
	
new String:sql_updateMarriageTarget[] = 
	"UPDATE weddings_marriages SET target_name = '%s' WHERE target_id = '%s';";
	
new String:sql_updateMarriageScore[] = 
	"UPDATE weddings_marriages SET score = (score + 1) WHERE source_id = '%s' OR target_id = '%s';";