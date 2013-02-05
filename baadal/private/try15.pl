#!/usr/bin/perl -w

# To be executed every 300 seconds
#
# Assumptions --- doms not reported are in shutdown mode
#             --- Removed doms are being treated as shutdown on their last host
#             --- COUNTER: cputotal, diskread, diskwrite, iorx, iotx
#             --- GAUGE:   memuse, memtotal, cpus
# Algorithm is in place integrated with MySQL
#      --- dbname: dbvmrrd  tablename: tbvmrrd
#      --- 17 fields in tbvmrrd
#      --- vmname, vmhost, cputotal, pcputotal, memuse, memtotal,
#      --- diskread, pdiskread, diskwrite, pdiskwrite, iorx, piorx,
#      --- iotx, piotx, time, ptime, cpus
# Tested: Detection of new dom, dom migration to new host, dom on the same host
#         shutdown and/or removed doms
#       
# TODO --- Sections indicates integration with rrd db
#      --- Creation and Upgrade of rrd dbs to be done
#      --- rrd graph generations

use Sys::Virt;
use XML::XPath;
use Data::Dumper;
use DBI;
use Net::Ping;

# Define a list of hosts
my @phosts = ("kvm01.iitd.ernet.in","kvm02.iitd.ernet.in","kvm03.iitd.ernet.in","kvm04.iitd.ernet.in",
	     "kvm05.iitd.ernet.in","kvm06.iitd.ernet.in","kvm07.iitd.ernet.in","kvm08.iitd.ernet.in",
	     "kvm09.iitd.ernet.in","kvm10.iitd.ernet.in","kvm11.iitd.ernet.in","kvm12.iitd.ernet.in",
	     "kvm13.iitd.ernet.in","kvm14.iitd.ernet.in","kvm15.iitd.ernet.in","kvm16.iitd.ernet.in",
	     "kvm21.iitd.ernet.in","kvm22.iitd.ernet.in","kvm23.iitd.ernet.in","kvm24.iitd.ernet.in",
	     "kvm25.iitd.ernet.in","kvm26.iitd.ernet.in","kvm27.iitd.ernet.in","kvm28.iitd.ernet.in",
	     "kvm29.iitd.ernet.in","kvm30.iitd.ernet.in","kvm31.iitd.ernet.in","kvm32.iitd.ernet.in",
	     "kvm33.iitd.ernet.in","kvm34.iitd.ernet.in","kvm35.iitd.ernet.in","kvm36.iitd.ernet.in");
my @hosts = ();

my $p=Net::Ping->new("icmp", 2);
 
foreach $host (@phosts) {
    if ($p->ping($host)) {
        push(@hosts, $host);
    } 
}

## Define a list of hosts
#my @hosts = ("kvm01.iitd.ernet.in","kvm02.iitd.ernet.in","kvm03.iitd.ernet.in","kvm04.iitd.ernet.in",
#	     "kvm05.iitd.ernet.in","kvm06.iitd.ernet.in","kvm07.iitd.ernet.in","kvm08.iitd.ernet.in",
#	     "kvm09.iitd.ernet.in","kvm10.iitd.ernet.in","kvm11.iitd.ernet.in","kvm12.iitd.ernet.in",
#	     "kvm13.iitd.ernet.in","kvm14.iitd.ernet.in","kvm15.iitd.ernet.in","kvm16.iitd.ernet.in",
#	     "kvm21.iitd.ernet.in","kvm22.iitd.ernet.in","kvm23.iitd.ernet.in","kvm24.iitd.ernet.in",
#	     "kvm25.iitd.ernet.in","kvm26.iitd.ernet.in","kvm27.iitd.ernet.in","kvm28.iitd.ernet.in",
#	     "kvm29.iitd.ernet.in","kvm30.iitd.ernet.in","kvm31.iitd.ernet.in","kvm32.iitd.ernet.in",
#	     "kvm33.iitd.ernet.in","kvm34.iitd.ernet.in","kvm35.iitd.ernet.in","kvm36.iitd.ernet.in");
#
# Define a hash to keep dom to host mapping from our db
my %domtohost = ();

# Define a hash to reflect processed/unprocessed doms in our db
my %domprocessed = ();

## Make connection to cloud db
#my $dbhc = DBI->connect('DBI:mysql:baadal;host=127.0.0.1', 'root', 'think4big')
#	 or die "Connection Error: $DBI::errstr\n";
#
## Fill in domtohost and domprocessed hashes from db
#my $selc = "select ip,runlevel,templateid from vm where name = ?;";
#my $selhandlec = $dbhc->prepare($selc);
#my $selt = "select ostype from template where id = ?;";
#my $selhandlet = $dbhc->prepare($selt);
#
## Make connection to our db
#my $dbh = DBI->connect('DBI:mysql:vmrrd1db;host=127.0.0.1', 'root', 'think4big')
#	 or die "Connection Error: $DBI::errstr\n";
#
## Fill in domtohost and domprocessed hashes from db
#my $sel = "select vmname,vmhost from tbvmrrd";
#my $selhandle = $dbh->prepare($sel);
#
#$selhandle->execute() or die "SQL Error: $DBI::errstr\n";
#
#while (my @data = $selhandle->fetchrow_array()) {
# 	#print "@data\n";
#	#print "$data[0]" . "|" .  "$data[1]" . " \n";
#	$domtohost{$data[0]}=$data[1];
#	$domprocessed{$data[0]}=0;
#} 
#$selhandle->finish;
#
## Process every dom in all hosts
#
## Mark the time stamp
#
#my $time = time();
#
foreach $host (@hosts) {
	my $uri = "qemu+ssh://root\@$host/system";
	my $vmm = Sys::Virt->new(uri => $uri);
    print "\nprocess $host:\n";
	my @doms = $vmm->list_domains();
	foreach $dom (@doms) {
		# db variables
		my ( $dbname, $dbhost, $dbcputime, $dbpcputime, $dbmemory, $dbmaxmem, $dbrd, $dbprd );
		my ( $dbwr, $dbpwr, $dbrx, $dbprx, $dbtx, $dbptx, $dbtime, $dbptime, $dbcpus );	
		# get domain data from host
		my $name =$dom->get_name();
        printf "%27s: ", $name;
        my $result;
#        print "/usr/bin/rrdtool fetch -r 3600 /var/www/cloudrrd1/$name\.rrd AVERAGE| /bin/grep -v nan | /bin/grep -v cpu | /bin/grep -v ", "\"^\$\""," | /usr/bin/awk -f /root/nck/mail\.pl\n";
        $result=`/usr/bin/rrdtool fetch -r 3600 /var/www/cloudrrd1/$name\.rrd AVERAGE| /bin/grep -v nan | /bin/grep -v cpu | /bin/grep -v \"^\$\" | /usr/bin/awk -f /root/nck/mail\.pl`;
        print $result;
    }
}
#		my $info = $dom->get_info();
#		my $cputime = $info->{cpuTime};
#		my $maxmem = $info->{maxMem};
#		my $memory = $info->{memory};
#		my $cpus = $info->{nrVirtCpu};
#		#print "$name: $info->{state},$maxmem,$memory,$cpus,$cputime \n";
#
#        # extract ip, runlevel, and ostype of $dom
#        $selhandlec->execute("$name") or die "SQL Error: $DBI::errstr\n";
#        my @data = $selhandlec->fetchrow_array();
#        #print @data,"\n\n";
#        my $ip = $data[0];
#        my $runlevel = $data[1];
#        my $template = $data[2];
#        $selhandlec->finish;
#        
#        $selhandlet->execute("$template") or die "SQL Error: $DBI::errstr\n";
#        @data = $selhandlet->fetchrow_array();
#        my $os = $data[0];
#        $selhandlet->finish;
#        my @memories;
#        if ($os eq "Windows"){
#            @memories = qx(/root/nck/check_winmem $ip mysecret 2>&1);
#            if (index($memories[0],"Timeout") == -1) {
#                chomp($memories[0]);
#                chomp($memories[1]);
#                $memory = $memories[0];
#                $maxmem = $memories[1];
#            }
#        } else {
#            @memories = qx(/root/nck/check_linuxmem $ip public 2>&1);
#            if (index($memories[0],"Timeout") == -1) {
#                chomp($memories[0]);
#                chomp($memories[1]);
#                $memory = $memories[0];
#                $maxmem = $memories[1];
#            }
#        }
#
#		#print "$name: $info->{state},$maxmem,$memory,$cpus,$cputime,$ip,$runlevel,$os \n";
#
#		my $xml = $dom->get_xml_description();
#		
#		my $xp = XML::XPath->new(xml => $xml);
#		my $nodes = $xp->find ("//devices/interface/target/\@dev");
#		my @ifaces;
#		foreach $node ($nodes->get_nodelist) {
#			push(@ifaces,$node->getData);
#		}
#
#		my $rx = 0;
#		my $tx = 0;
#		foreach $iface (@ifaces) {
#			#print "$iface: ";
#			my $info = $dom->interface_stats($iface);
#			$rx += $info->{rx_bytes};
#			$tx += $info->{tx_bytes};
#		}
#		#print "rx = $rx, tx = $tx\n";
#
#		$nodes = $xp->find ("//devices/disk/target/\@dev");
#		my @disks;
#		foreach $node ($nodes->get_nodelist) {
#			 push(@disks,$node->getData);
#		}
#
#		my $rd = 0;
#		my $wr = 0;
#		foreach $disk (@disks) {
#			#print "$disk: ";
#			my $info = $dom->block_stats($disk);
#			$rd += $info->{rd_bytes};
#			$wr += $info->{wr_bytes};
#		}
#		#print "rd = $rd, wr = $wr\n";
#
#		# Current doman data avaialable now
#		# $name, $host, $cputime, $memory, $maxmem, $rd, $wr, $rx, $tx, $cpus
#
#		#print "-----\n";
#	    $time = time();	
#		# Initialize domain data as it exits in our db to br used later for rrd updates
#		# $dbname, $dbhost, $dbcputime, $dbpcputime, $dbmemory, $dbmaxmem, $dbrd, $dbprd, 
#		# $dbwr, $dbper, $dbrx, $dbprx, $dbtx, $dbptx, $dbtime, $dbptime, $dbcpus
#		if (defined($domtohost{$name})) {# dom exists fetch db data
#			my $sel1 = "select * from tbvmrrd where vmname = ?;";
#			my $sel1handle = $dbh->prepare($sel1);
#
#			$sel1handle->execute($name) or die "SQL Error: $DBI::errstr\n";
#
#			my @data = $sel1handle->fetchrow_array();
#			$dbname=$data[0]; $dbhost=$data[1]; $dbcputime=$data[2]; $dbpcputime=$data[3]; 
#			$dbmemory=$data[4]; $dbmaxmem=$data[5]; $dbrd=$data[6]; $dbprd=$data[7]; 
#			$dbwr=$data[8]; $dbpwr=$data[9]; $dbrx=$data[10]; $dbprx=$data[11]; $dbtx=$data[12]; 
#			$dbptx=$data[13]; $dbtime=$data[14]; $dbptime=$data[15]; $dbcpus=$data[16]; $dblevel=$data[17];
#		}
#
#
#		if (!defined($domtohost{$name})) {
#			# New dom
#			my $ins = "insert into tbvmrrd values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
#			my $inshandle = $dbh->prepare($ins);
#			$inshandle->execute($name, $host, $cputime, 0, $memory, $maxmem, $rd, 0, $wr, 0, $rx, 0, $tx, 0, $time, 0, $cpus, $runlevel) or die "SQL Error: $DBI::errstr\n";
#			$inshandle->finish;
#			# TODO -- create rrd db
#			# TODO -- update rrd db
#			qx(rrdtool create /var/www/cloudrrd1/$name.rrd DS:cputime:COUNTER:600:U:U DS:memory:GAUGE:600:0:20000000 DS:maxmem:GAUGE:600:0:20000000 DS:rd:COUNTER:600:U:U DS:wr:COUNTER:600:U:U DS:rx:COUNTER:600:U:U DS:tx:COUNTER:600:U:U DS:cpus:GAUGE:600:0:32 DS:level:GAUGE:600:0:4 RRA:MIN:0:360:576 RRA:MIN:0:30:576 RRA:MIN:0:7:576 RRA:AVERAGE:0:360:576 RRA:AVERAGE:0:30:576 RRA:AVERAGE:0:7:576 RRA:AVERAGE:0:1:576 RRA:MAX:0:360:576 RRA:MAX:0:30:576 RRA:MAX:0:7:576);
#			qx(rrdtool update /var/www/cloudrrd1/$name.rrd $time:$cputime:$memory:$maxmem:$rd:$wr:$rx:$tx:$cpus:$runlevel);
#
#			# Add $dom in domtohost and domprocessed hashes
#			$domtohost{$name} = $host;
#			$domprocessed{$name} = 1;
#		} else {
#			if ($domtohost{$name} eq $host) { # dom on the same host
#				# update only current values in db and time
#				my ($update);
#				if ( $cputime < $dbcputime ) {# dom migrated to other host and back
#					# There would be a loss of data for a few minutes
#					$update = "update tbvmrrd set pcputotal = pcputotal + cputotal, cputotal = $cputime, pdiskread = pdiskread + diskread, diskread = $rd, pdiskwrite = pdiskwrite + diskwrite, diskwrite = $wr, piorx = piorx + iorx, iorx = $rx, piotx = piotx + iotx, iotx = $tx, memuse = $memory, memtotal = $maxmem, time = $time, ptime = $time, cpus = $cpus, level = $runlevel where vmname = ?;";
#				} else {
#					$update = "update tbvmrrd set cputotal = $cputime, diskread = $rd, diskwrite = $wr, iorx = $rx, iotx = $tx, memuse = $memory, memtotal = $maxmem, time = $time, cpus = $cpus, level = $runlevel where vmname = ?;";
#				}
#				my $updatehandle = $dbh->prepare($update);
#				$updatehandle->execute($name) or die "SQL Error: $DBI::errstr\n";
#				$updatehandle->finish;
#				# TODO --- update rrd db with current values + pvalues for COUNTER, and current values for GAUGE
#				my ($ucputime, $urd, $uwr, $urx, $utx);
#				if ( $cputime < $dbcputime ) {# dom migrated to other host and back
#					$ucputime = $cputime + $dbcputime + $dbpcputime;
#					$urd = $rd + $dbrd + $dbprd;
#					$uwr = $wr + $dbwr + $dbpwr;
#					$urx = $rx + $dbrx + $dbprx;
#					$utx = $tx + $dbtx + $dbptx;
#				} else {
#					$ucputime = $cputime + $dbpcputime;
#					$urd = $rd + $dbprd;
#					$uwr = $wr + $dbpwr;
#					$urx = $rx + $dbprx;
#					$utx = $tx + $dbptx;
#				}
#                qx(rrdtool update /var/www/cloudrrd1/$name.rrd $time:$ucputime:$memory:$maxmem:$urd:$uwr:$urx:$utx:$cpus:$runlevel);
#				# show dom has been processed
#				$domprocessed{$name} = 1;
#			} else { # dom has just been migrated to a new host
#                                # update current values in db, vmhost, time, ptime, and pvalues<-pvalue+values(db)
#				my $update = "update tbvmrrd set vmhost = \'$host\', pcputotal = pcputotal + cputotal, cputotal = $cputime, pdiskread = pdiskread + diskread, diskread = $rd, pdiskwrite = pdiskwrite + diskwrite, diskwrite = $wr, piorx = piorx + iorx, iorx = $rx, piotx = piotx + iotx, iotx = $tx, memuse = $memory, memtotal = $maxmem, time = $time, ptime = $time, cpus = $cpus, level = $runlevel where vmname = ?;";
#
#				my $updatehandle = $dbh->prepare($update);
#				$updatehandle->execute($name) or die "SQL Error: $DBI::errstr\n";
#				# TODO --- update rrd db with values(db) + pvalues + value(current)  for COUNTER, and current values for GAUGE
#				$ucputime = $cputime + $dbcputime + $dbpcputime;
#				$urd = $rd + $dbrd + $dbprd;
#				$uwr = $wr + $dbwr + $dbpwr;
#				$urx = $rx + $dbrx + $dbprx;
#				$utx = $tx + $dbtx + $dbptx;
#				qx(rrdtool update /var/www/cloudrrd1/$name.rrd $time:$ucputime:$memory:$maxmem:$urd:$uwr:$urx:$utx:$cpus:$runlevel);
#                                # show dom has been processed
#                                $domprocessed{$name} = 1;
#			}
#		}
#	}	
#}
## check for shutdown doms $dbh->disconnect; assume not migrated
#$time = time();
#foreach $dom (sort keys %domprocessed) {
#	if ($domprocessed{$dom} == 0) { # dom unprocessed
#		# update db putting 0 in GAUGEs, and update time
#		#print "Unprocessed: $dom: $domprocessed{$dom}\n";
#		my $update = "update tbvmrrd set memuse = 0, memtotal = 0, time = $time, cpus = 0, level = 0 where vmname = ?;";
#
#		my $updatehandle = $dbh->prepare($update);
#		$updatehandle->execute($dom) or die "SQL Error: $DBI::errstr\n";
#		# TODO --- update rrd db values(db) + pvalues for COUNTER, and 0 for GAUGE
#		# get data from db
#		my $sel1 = "select * from tbvmrrd where vmname = ?;";
#		my $sel1handle = $dbh->prepare($sel1);
#
#		$sel1handle->execute($dom) or die "SQL Error: $DBI::errstr\n";
#
#		my @data = $sel1handle->fetchrow_array();
#		$dbname=$data[0]; $dbhost=$data[1]; $dbcputime=$data[2]; $dbpcputime=$data[3]; 
#		$dbmemory=$data[4]; $dbmaxmem=$data[5]; $dbrd=$data[6]; $dbprd=$data[7]; 
#		$dbwr=$data[8]; $dbpwr=$data[9]; $dbrx=$data[10]; $dbprx=$data[11]; $dbtx=$data[12]; 
#		$dbptx=$data[13]; $dbtime=$data[14]; $dbptime=$data[15]; $dbcpus=$data[16]; $dblevel=$data[17]; 
#		my ($ucputime, $urd, $uwr, $urx, $utx);
#		$ucputime = $dbcputime + $dbpcputime;
#		$urd = $dbrd + $dbprd;
#		$uwr = $dbwr + $dbpwr;
#		$urx = $dbrx + $dbprx;
#		$utx = $dbtx + $dbptx;
#		qx(rrdtool update /var/www/cloudrrd1/$dom.rrd $time:$ucputime:0:0:$urd:$uwr:$urx:$utx:0:$dblevel);
#	} 
#}
#
## close db connection
#$dbh->disconnect;
#$dbhc->disconnect;
