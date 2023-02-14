# iRODS Chunked Data Set Transfer

This is a proof of Edwin Skidmore's concept for chunked data transfer from iRODS to a client.

Transferring a large set of small files takes a very long time using standard iRODS mechanisms.
Large files have a higher goodput than small ones, very large files, i.e., files too large to be
stored entirely in memory, the goodput can be less than it is for files that do fit in memory. If
the data set is archived into a tar file, and the tar file is split into large chunks, the transfer
will take significantly less time. The hope is that even with the overhead of chunking the data set
prior to transfer and reconstituting it afterwards, the overall time will be less than a set of
`iget` processes running in parallel.

The chunking happens on each resource server. Files on separate resource servers are archived,
chunked, and registered into iRODS separately. This way the chunking on each resource server can
happen in parallel. The script `chunk-resc` needs to be deployed on each resource server. The
script `chunk` is the driver. It chunks the entire data set, calling `chunk-resc` in parallel on the
relevant resource servers.

Once the data set is chunked, the client uses the script `chunk-get` to download the chunks,
reconstitute the tar files, and extract the data set. It also parallelizes this operation over the
resource servers.
