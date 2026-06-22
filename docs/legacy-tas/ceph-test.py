import boto
import boto.s3.connection
access_key = '0XUE6CGXNTENQ4F06BX7'
secret_key = 'ehepFsMZVT7qZND8XVtv9c4YaB2Zuj2grgXG4Bwo'

conn = boto.connect_s3(
        aws_access_key_id = access_key,
        aws_secret_access_key = secret_key,
        host = 'ceph.lab.sampsoftware.net',
        #is_secure=False,               # uncomment if you are not using ssl
        calling_format = boto.s3.connection.OrdinaryCallingFormat(),
        )

for bucket in conn.get_all_buckets():
        print("{name}\t{created}".format(
                name = bucket.name,
                created = bucket.creation_date,
        ))