# PowerShell script to deploy authority functions
# Requires PostgreSQL connection details

# Set your PostgreSQL connection parameters
$env:PGPASSWORD = 'your_password_here'
$hostname = 'localhost'
$port = '5432'
$database = 'easytax'
$username = 'postgres'
$sqlFile = 'authority_cloud_functions.sql'

# Full path to psql if available
$psqlPath = "$env:ProgramFiles\PostgreSQL\*in\psql.exe"

if (Test-Path $psqlPath) {
    $psqlExe = (Get-Item $psqlPath).FullName
    & $psqlExe -h $hostname -p $port -U $username -d $database -f $sqlFile
} else {
    Write-Host "psql not found. Please install PostgreSQL or add it to your PATH"
    Write-Host "You can manually run the SQL file in Supabase Dashboard -> SQL Editor"
}
