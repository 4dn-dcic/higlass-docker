from flask import Flask
from flask import Response
import os
from shutil import copy


def create_app():
    app = Flask(__name__)
    app.config['DEBUG'] = False


    @app.route('/cp/<path:loc>',  methods=['POST'])
    def copy_folder(loc):

        base_path = '/data/media/'
        base_path_new = base_path + 'beddbs/'
        file_loc = str(loc)
        file_orig = base_path + file_loc
        file_new = base_path_new + file_loc
        dirname_new = os.path.dirname(file_new)

        if not os.path.exists(dirname_new):
            os.makedirs(dirname_new, mode=0o775, exist_ok=True)

        if(os.path.exists(file_orig) and not os.path.exists(file_new) and file_orig.endswith(".beddb")):
            try:
                copy(file_orig, file_new)
            except IOError as e:
                return Response("Unable to copy file. %s" % e, status=500)
        else:
            return Response("File does not exist or has already been copied: %s" % file_orig, status=500)

        return Response("Ok", status=200)

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=8005) 
